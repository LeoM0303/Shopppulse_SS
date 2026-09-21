# Partial backend configuration: the storage account name is globally unique and the
# state key differs per environment, so the values live in backend.hcl and are passed with
#   terraform init -backend-config=backend.hcl
# Run scripts/bootstrap-state.ps1 once to create the storage account and generate that file.
#
# use_azuread_auth makes Terraform reach the state blob with your Entra identity instead of
# a storage account key, which is what lets CI authenticate through OIDC with no stored secret.
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
