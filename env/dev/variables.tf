variable "location" {
  description = "The location of the resources."
  type        = string
}

variable "subnet_prefixes" {
  description = "The subnet prefixes for the virtual network."
  type        = map(string)
}

variable "address_space" {
  description = "The address space for the virtual network."
  type        = list(string)
}

variable "app_location" {
  description = "Region for the App Service Plan and web app (East US has no App Service quota on this subscription)."
  type        = string
}

variable "ingest_principal_id" {
  description = "The object ID of the user or service principal that runs the ingestion script."
  type        = string
}