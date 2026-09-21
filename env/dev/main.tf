data "azurerm_client_config" "current" {

}

module "networking" {
  source = "../../modules/networking"

  location             = var.location
  subnet_prefixes      = var.subnet_prefixes
  address_space        = var.address_space
  cognitive_account_id = module.compute.cognitive_account_id
}

module "compute" {
  source = "../../modules/compute"

  location = var.location
}

module "database" {
  source = "../../modules/database"

  location = var.location
}