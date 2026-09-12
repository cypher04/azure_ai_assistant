// gitlab identity configuration 
data "azurerm_client_config" "current" {
}


resource "azuread_application" "gitlab_app" {
  display_name     = "gitlab-ai-assistant"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "gitlab_sp" {
  client_id = azuread_application.gitlab_app.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "gitlab_fed_id_cred" {
  issuer                = var.gitlab_base_url
  subject               = "project_path:${var.gitlab_namespace}/${var.gitlab_project_name}:ref_type:branch:ref:${var.default_branch}"
  audiences             = [var.gitlab_base_url]
  application_id        = azuread_application.gitlab_app.id
  display_name = "gitlab-federated-identity-credential"
}