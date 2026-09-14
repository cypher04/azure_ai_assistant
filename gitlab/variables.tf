// gtilab variables

variable "gitlab_token" {
  description = "GitLab personal access token"
  type        = string
  sensitive   = true
}

variable "gitlab_base_url" {
  description = "GitLab base URL"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "gitlab_namespace" {
  description = "GitLab namespace"
  type        = string
}

variable "gitlab_project_name" {
  description = "GitLab project name"
  type        = string
}

variable "default_branch" {
  description = "Default branch for the GitLab project"
  type        = string
}