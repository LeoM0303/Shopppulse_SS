module "keyvault_secrets" {
  source = "./modules/keyvault/secrets"

  key_vault_id = module.keyvault.key_vault_id
  secrets      = local.key_vault_secrets

  depends_on = [
    time_sleep.wait_for_kv_rbac,
    module.postgresql,
    module.redis,
    module.servicebus,
  ]
}
