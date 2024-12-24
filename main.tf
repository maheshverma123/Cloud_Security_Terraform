# Azure Provider
provider "azurerm" {
  subscription_id = "64d42c3e-606a-47e4-8b51-8327c48d2efc"
  features {}
}

# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "RSA2_resource"
  location = "West US"
}

# Virtual Network
resource "azurerm_virtual_network" "example" {
  name                = "RSA_VNet"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet for Bastion
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [azurerm_virtual_network.example]
}

# Subnet for Function App
resource "azurerm_subnet" "function_app" {
  name                 = "FunctionAppSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]

  depends_on = [azurerm_virtual_network.example]
}

# NSG for Function App Subnet
resource "azurerm_network_security_group" "function_app_nsg" {
  name                = "FunctionAppNSG"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.example]
}

# Associate NSG with Function App Subnet
resource "azurerm_subnet_network_security_group_association" "function_app_nsg_association" {
  subnet_id                 = azurerm_subnet.function_app.id
  network_security_group_id = azurerm_network_security_group.function_app_nsg.id

  depends_on = [azurerm_subnet.function_app, azurerm_network_security_group.function_app_nsg]
}

# Public IP for Bastion
resource "azurerm_public_ip" "bastion_ip" {
  name                = "example-bastion-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.example]
}

# Generate a unique name for Bastion Host using a random string
resource "random_id" "bastion_name" {
  byte_length = 8
}

# Bastion Host
resource "azurerm_bastion_host" "example" {
  name                = "azurebastionhost-${random_id.bastion_name.hex}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                 = "example-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }

  depends_on = [azurerm_subnet.bastion, azurerm_public_ip.bastion_ip]
}

# Random ID for Storage Account Suffix
resource "random_id" "storage_suffix" {
  byte_length = 4  # Shorten to ensure name is under 24 characters
}

# Storage Account for Function App
resource "azurerm_storage_account" "example" {
  name                     = "rsawebstorage${random_id.storage_suffix.hex}"
  resource_group_name       = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier              = "Standard"
  account_replication_type = "LRS"

  depends_on = [azurerm_resource_group.example]
}

# App Service Plan
resource "azurerm_service_plan" "example" {
  name                     = "RSA_AppServicePlan"
  location                 = azurerm_resource_group.example.location
  resource_group_name      = azurerm_resource_group.example.name
  sku_name                 = "B2"
  os_type                  = "Linux"

  depends_on = [azurerm_resource_group.example]
}

# Function App
resource "azurerm_linux_function_app" "example" {
  name                       = "RSAFunctionApp"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  service_plan_id            = azurerm_service_plan.example.id
  storage_account_name       = azurerm_storage_account.example.name
  storage_account_access_key = azurerm_storage_account.example.primary_access_key

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }

  depends_on = [
    azurerm_service_plan.example,
    azurerm_storage_account.example
  ]
}

# Output Function App URL
output "function_app_url" {
  value = azurerm_linux_function_app.example.default_hostname
}