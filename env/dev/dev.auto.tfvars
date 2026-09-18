location = "East us"
subnet_prefixes = {
  hub-subnet         = "10.1.0.0/24",
  firewall-subnet    = "10.1.1.0/24",
  app-gateway-subnet = "10.1.2.0/24",
  nat-gateway-subnet = "10.1.3.0/24",
  
  ai-spoke-subnet   = "10.2.0.0/24",
  data-spoke-subnet = "10.3.0.0/24",
  web               = "10.4.0.0/24",
  security          = "10.5.0.0/24"
}

address_space = [
  "10.1.0.0/16",
  "10.2.0.0/16",
  "10.3.0.0/16",
  "10.4.0.0/16",
  "10.5.0.0/16"
]


