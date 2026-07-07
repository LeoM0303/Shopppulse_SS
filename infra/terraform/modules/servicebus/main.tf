resource "azurerm_servicebus_namespace" "this" {
  name                = "${var.name_prefix}-servicebus"
  location            = var.location
  resource_group_name = var.resource_group.name
  sku                 = var.sku
  tags                = var.tags

  minimum_tls_version = "1.2"
}

resource "azurerm_servicebus_queue" "this" {
  for_each = toset(var.queue_names)

  name         = each.value
  namespace_id = azurerm_servicebus_namespace.this.id

  # Mirrors servicebus-config.json defaults for sales-events
  default_message_ttl                     = "PT1H"
  lock_duration                           = "PT1M"
  max_delivery_count                      = 3
  dead_lettering_on_message_expiration    = false
  duplicate_detection_history_time_window = "PT20S"
  requires_duplicate_detection            = false
  requires_session                        = false
}
