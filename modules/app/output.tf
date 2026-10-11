output "web_app_id" {
  value = azurerm_linux_web_app.app-service.id
}

output "web_app_name" {
  value = azurerm_linux_web_app.app-service.name
}
output "web_app_url" {
  value = "https://${azurerm_linux_web_app.app-service.default_hostname}"
}