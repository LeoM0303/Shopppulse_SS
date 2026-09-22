resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-logs"
  location            = var.location
  resource_group_name = var.resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "${var.name_prefix}-appi"
  location            = var.location
  resource_group_name = var.resource_group.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  sampling_percentage = var.sampling_percentage
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "this" {
  name                = "${var.name_prefix}-alerts"
  resource_group_name = var.resource_group.name
  short_name          = substr(replace(var.name_prefix, "-", ""), 0, 12)
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email == null ? [] : [var.alert_email]

    content {
      name                    = "oncall"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# Send platform logs and metrics of every resource we manage to one workspace,
# so an incident can be investigated from a single place.
resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_target_ids

  name                       = "to-log-analytics"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = contains(var.metrics_only_targets, each.key) ? [] : [1]

    content {
      category_group = "allLogs"
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# --- Cluster health ---

resource "azurerm_monitor_metric_alert" "aks_node_cpu" {
  count = var.aks_enabled ? 1 : 0

  name                = "${var.name_prefix}-aks-node-cpu"
  resource_group_name = var.resource_group.name
  scopes              = [var.aks_cluster_id]
  description         = "Average node CPU above 80% for 15 minutes — check for a hot pod or scale the workload pool."
  severity            = 2
  window_size         = "PT15M"
  frequency           = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

resource "azurerm_monitor_metric_alert" "aks_node_memory" {
  count = var.aks_enabled ? 1 : 0

  name                = "${var.name_prefix}-aks-node-memory"
  resource_group_name = var.resource_group.name
  scopes              = [var.aks_cluster_id]
  description         = "Working set memory above 85% for 15 minutes — pods are close to eviction."
  severity            = 2
  window_size         = "PT15M"
  frequency           = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# --- Database health ---

resource "azurerm_monitor_metric_alert" "postgres_cpu" {
  name                = "${var.name_prefix}-postgres-cpu"
  resource_group_name = var.resource_group.name
  scopes              = [var.postgres_server_id]
  description         = "PostgreSQL CPU above 80% for 15 minutes."
  severity            = 2
  window_size         = "PT15M"
  frequency           = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

resource "azurerm_monitor_metric_alert" "postgres_storage" {
  name                = "${var.name_prefix}-postgres-storage"
  resource_group_name = var.resource_group.name
  scopes              = [var.postgres_server_id]
  description         = "PostgreSQL storage above 85% — grow the disk before it fills up, shrinking is not possible."
  severity            = 1
  window_size         = "PT15M"
  frequency           = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# --- Application health, driven by Container Insights data ---

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pod_restarts" {
  count = var.aks_enabled ? 1 : 0

  name                 = "${var.name_prefix}-pod-restarts"
  resource_group_name  = var.resource_group.name
  location             = var.location
  description          = "A pod in the application namespace restarted more than 3 times in 30 minutes — likely a crash loop."
  severity             = 2
  evaluation_frequency = "PT10M"
  window_duration      = "PT30M"
  scopes               = [azurerm_log_analytics_workspace.this.id]
  tags                 = var.tags

  criteria {
    query                   = <<-KQL
      KubePodInventory
      | where Namespace == "${var.k8s_namespace}"
      | summarize restarts = max(PodRestartCount) by Name
      | where restarts > 3
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "worker_errors" {
  count = var.aks_enabled ? 1 : 0

  name                 = "${var.name_prefix}-container-errors"
  resource_group_name  = var.resource_group.name
  location             = var.location
  description          = "More than 20 ERROR lines in container logs within 15 minutes."
  severity             = 3
  evaluation_frequency = "PT10M"
  window_duration      = "PT15M"
  scopes               = [azurerm_log_analytics_workspace.this.id]
  tags                 = var.tags

  criteria {
    query                   = <<-KQL
      ContainerLogV2
      | where PodNamespace == "${var.k8s_namespace}"
      | where LogMessage has "ERROR" or LogLevel == "error"
      | summarize errors = count()
    KQL
    time_aggregation_method = "Total"
    metric_measure_column   = "errors"
    threshold               = 20
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }
}
