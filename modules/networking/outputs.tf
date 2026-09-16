

output "subnet_ids" {
  value = {
    hub_subnet_id        = azurerm_subnet.hub-subnet.id
    ai_spoke_subnet_id   = azurerm_subnet.ai-spoke-subnet.id
    data_spoke_subnet_id = azurerm_subnet.data-spoke-subnet.id
  }
}

output "route_table_ids" {
  value = {
    hub_route_table_id        = azurerm_route_table.hub-route-table.id
    ai_spoke_route_table_id   = azurerm_route_table.ai-spoke-route-table.id
    data_spoke_route_table_id = azurerm_route_table.data-spoke-route-table.id
  }
}