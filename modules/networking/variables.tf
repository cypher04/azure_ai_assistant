variable "location" {
  description = "The location where resources will be created"
  type        = string
}

variable "address_space" {
  description = "The address space for the virtual network"
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "The subnet prefixes for the virtual network"
  type        = map(string)
}

variable "cognitive_account_id" {
  description = "The ID of the cognitive account"
  type        = string
}