# Single public entry point. Everything else in the cluster is ClusterIP, so the
# only address reachable from the internet is the ingress controller's load
# balancer, and it terminates TLS.

resource "kubernetes_namespace" "ingress_nginx" {
  count = local.ingress_enabled ? 1 : 0

  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }

  depends_on = [module.aks]
}

resource "helm_release" "ingress_nginx" {
  count = local.ingress_enabled ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_chart_version
  namespace  = kubernetes_namespace.ingress_nginx[0].metadata[0].name

  # The cluster can be busy pulling the controller image on a cold node pool.
  timeout = 600
  atomic  = true

  set {
    name  = "controller.replicaCount"
    value = var.ingress_replica_count
  }

  # System nodes are tainted for critical addons only, so the controller has to
  # land on the workload pool like everything else.
  set {
    name  = "controller.nodeSelector.workload"
    value = "apps"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  # Azure's load balancer probes the health endpoint rather than the data path.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
}

# A self-signed certificate keeps HTTPS working without a registered domain.
# The moment there is real DNS, replace this with cert-manager and a Let's
# Encrypt issuer: the Ingress already references the secret by name, so nothing
# else has to change.
resource "tls_private_key" "ingress" {
  count = local.ingress_enabled ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ingress" {
  count = local.ingress_enabled ? 1 : 0

  private_key_pem = tls_private_key.ingress[0].private_key_pem

  subject {
    common_name  = var.ingress_hostname
    organization = var.project_name
  }

  dns_names             = [var.ingress_hostname]
  validity_period_hours = 8760
  early_renewal_hours   = 720

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

resource "kubernetes_secret" "ingress_tls" {
  count = local.ingress_enabled ? 1 : 0

  metadata {
    name      = "shoppulse-tls"
    namespace = kubernetes_namespace.shoppulse[0].metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.ingress[0].cert_pem
    "tls.key" = tls_private_key.ingress[0].private_key_pem
  }
}
