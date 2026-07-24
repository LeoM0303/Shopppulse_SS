resource "kubernetes_namespace" "shoppulse" {
  count = var.enable_aks ? 1 : 0

  metadata {
    name = var.k8s_namespace
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }

  depends_on = [module.aks]
}

resource "kubernetes_service_account" "keda_servicebus" {
  count = var.enable_aks ? 1 : 0

  metadata {
    name      = var.keda_service_account_name
    namespace = kubernetes_namespace.shoppulse[0].metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = module.identity[0].keda_identity.client_id
    }
  }
}

resource "kubernetes_service_account" "worker" {
  count = var.enable_aks ? 1 : 0

  metadata {
    name      = var.worker_service_account_name
    namespace = kubernetes_namespace.shoppulse[0].metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = module.identity[0].worker_identity.client_id
    }
  }
}

resource "kubernetes_service_account" "api" {
  count = var.enable_aks ? 1 : 0

  metadata {
    name      = var.api_service_account_name
    namespace = kubernetes_namespace.shoppulse[0].metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = module.identity[0].api_identity.client_id
    }
  }
}
