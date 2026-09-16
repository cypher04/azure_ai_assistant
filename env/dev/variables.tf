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