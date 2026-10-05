// gitlab roles configuration 
resource "azurerm_role_assignment" "gitlab_role_assignment" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gitlab_sp.object_id
}

resource "azurerm_role_assignment" "gitlab_sp_role_assignment" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.gitlab_sp.object_id
}



// role assignment for service principal to access state storage   
resource "azurerm_role_assignment" "gitlab_state_role_assignment" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/azure0ai0assistant-rg/providers/Microsoft.Storage/storageAccounts/azure0ai0assistantstate"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.gitlab_sp.object_id
}

/////////////////////   role assignment for app     //////////////////////
resource "azurerm_role_assignment" "gitlab_ai_assistant_app_role_assignment" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Website Contributor"
  principal_id         = azuread_service_principal.gitlab_ai_assistant_sp_app.object_id
}

