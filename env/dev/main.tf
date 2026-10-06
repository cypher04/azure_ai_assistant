data "azurerm_client_config" "current" {
}

module "networking" {
  source               = "../../modules/networking"
  location             = var.location
  subnet_prefixes      = var.subnet_prefixes
  address_space        = var.address_space
  cognitive_account_id = module.compute.cognitive_account_id
}

module "compute" {
  source        = "../../modules/compute"
  ai_storage_id = module.database.ai_storage_id
  location      = var.location
}

module "database" {
  source   = "../../modules/database"
  location = var.location
}

module "app" {
  source   = "../../modules/app"
  location = var.location
  search_service_id = module.compute.search_service_id
  cognitive_account_id = module.compute.cognitive_account_id
  openai_endpoint = module.compute.openai_endpoint
  search_endpoint = module.compute.search_endpoint
}