resource "gitlab_project_variable" "gitlab_token" {
  project = data.gitlab_project.project.id
  key     = "AZUREAD_GITLAB_TOKEN"
  value   = var.gitlab_token
  masked  = false
  protected = true
}

resource "gitlab_project_variable" "tenant_id" {
  project = data.gitlab_project.project.id
  key     = "AZUREAD_TENANT_ID"
  value   = var.tenant_id
  masked  = false
  protected = true
}

resource "gitlab_project_variable" "subscription_id" {
  project = data.gitlab_project.project.id
  key     = "AZUREAD_SUBSCRIPTION_ID"
  value   = var.subscription_id
  masked  = false
  protected = true
}

resource "gitlab_project_variable" "client_id" {
  project = data.gitlab_project.project.id
  key     = "AZUREAD_CLIENT_ID"
  value   = azuread_application.gitlab_app.client_id
  masked  = false
  protected = true
}