output "cognitive_account_id" {
  value = azurerm_cognitive_account.cognitive-account.id
}

output "search_endpoint" {
  value = azurerm_search_service.search-service.endpoint
}

output "openai_endpoint" {
  value = azurerm_cognitive_account.cognitive-account.endpoint
}

output "search_service_id" {
  value = azurerm_search_service.search-service.id
}



# output "search_api_key" {
#   value = azurerm_search_service.search-service.primary_key
#   sensitive = true
# }