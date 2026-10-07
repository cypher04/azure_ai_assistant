variable "location" {
  description = "The location of the app service."
  type        = string
}


variable "search_endpoint" {
  description = "The endpoint of the Azure Search service."
  type        = string
}

variable "openai_endpoint" {
  description = "The endpoint of the Azure OpenAI service."
  type        = string
}

variable "cognitive_account_id" {
  description = "The ID of the Azure Cognitive Account."
  type        = string
}


variable "search_service_id" {
  description = "The ID of the Azure Search service."
  type        = string
}

variable "subnet_ids" {
  description = "The IDs of the subnets for the app service."
  type        = list(string)
}