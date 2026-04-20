# Terraform configuration for Azure PoC Setup
# Extends the PoC environment to include:
# - Azure Application Gateway + WAF
# - Azure Key Vault
# - Azure Monitor + Log Analytics
# - GitHub Actions DevSecOps pipeline support

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# Variables for customization
variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "MyPoCRG"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "MyPoC-VNet"
}

variable "appgw_subnet_name" {
  description = "Name of the Application Gateway subnet"
  type        = string
  default     = "AppGatewaySubnet"
}

variable "log_analytics_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default     = "MyPoC-LogAnalytics"
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault"
  type        = string
  default     = "mypoc-keyvault-001"
}

variable "apim_name" {
  description = "Name of the API Management instance"
  type        = string
  default     = "MyPoCAPIM"
}

variable "api_id" {
  description = "ID of the sample API"
  type        = string
  default     = "mybasicapi"
}

variable "api_name" {
  description = "Display name of the sample API"
  type        = string
  default     = "My Basic API"
}

variable "api_path" {
  description = "Path for the API"
  type        = string
  default     = "api"
}

variable "service_url" {
  description = "Backend service URL for the API"
  type        = string
  default     = "https://httpbin.org"
}

variable "appgw_public_ip_name" {
  description = "Application Gateway public IP name"
  type        = string
  default     = "MyPoC-AppGW-PIP"
}

variable "certificate_pfx_path" {
  description = "Path to the PFX certificate file for App Gateway HTTPS"
  type        = string
  default     = ""
}

variable "certificate_password" {
  description = "Password for the PFX certificate"
  type        = string
  default     = "PfxPassword123!"
  sensitive   = true
}

# Resource Group
resource "azurerm_resource_group" "poc_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "PoC"
    Purpose     = "API Management Demo"
  }
}

# Virtual Network and Subnet
resource "azurerm_virtual_network" "poc_vnet" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.poc_rg.location
  resource_group_name = azurerm_resource_group.poc_rg.name
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = var.appgw_subnet_name
  resource_group_name  = azurerm_resource_group.poc_rg.name
  virtual_network_name = azurerm_virtual_network.poc_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = var.appgw_public_ip_name
  location            = azurerm_resource_group.poc_rg.location
  resource_group_name = azurerm_resource_group.poc_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "poc_workspace" {
  name                = var.log_analytics_name
  location            = azurerm_resource_group.poc_rg.location
  resource_group_name = azurerm_resource_group.poc_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Key Vault
resource "azurerm_key_vault" "poc_kv" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.poc_rg.location
  resource_group_name         = azurerm_resource_group.poc_rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enabled_for_deployment      = true
  enabled_for_disk_encryption = true
  enabled_for_template_deployment = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
    ]
  }
}

resource "azurerm_key_vault_secret" "backend_secret" {
  name         = "api-backend-secret"
  value        = "SuperSecretValue123!"
  key_vault_id = azurerm_key_vault.poc_kv.id
}

# API Management Instance
resource "azurerm_api_management" "poc_apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.poc_rg.location
  resource_group_name = azurerm_resource_group.poc_rg.name
  publisher_name      = "My Organization"
  publisher_email     = "admin@myorg.com"

  sku_name = "Developer_1"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "PoC"
  }
}

# Grant APIM managed identity Key Vault access
resource "azurerm_key_vault_access_policy" "apim_kv_policy" {
  key_vault_id = azurerm_key_vault.poc_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_api_management.poc_apim.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# API in API Management
resource "azurerm_api_management_api" "poc_api" {
  name                = var.api_id
  resource_group_name = azurerm_resource_group.poc_rg.name
  api_management_name = azurerm_api_management.poc_apim.name
  revision            = "1"
  display_name        = var.api_name
  path                = var.api_path
  protocols           = ["https"]
  service_url         = var.service_url

  subscription_required = false
}

# Sample GET Operation
resource "azurerm_api_management_api_operation" "poc_operation" {
  operation_id        = "getSample"
  api_name            = azurerm_api_management_api.poc_api.name
  api_management_name = azurerm_api_management.poc_apim.name
  resource_group_name = azurerm_resource_group.poc_rg.name
  display_name        = "Get Sample Data"
  method              = "GET"
  url_template        = "/get"
  description         = "Retrieves sample data from the backend service"

  response {
    status_code = 200
  }
}

# Application Gateway with WAF
resource "azurerm_application_gateway" "poc_appgw" {
  name                = "MyPoC-AppGateway"
  location            = azurerm_resource_group.poc_rg.location
  resource_group_name = azurerm_resource_group.poc_rg.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ipcfg"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  # Frontend port: HTTPS when certificate exists, HTTP otherwise
  frontend_port {
    name = "appgw-frontend-port"
    port = var.certificate_pfx_path != "" ? 443 : 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name  = "apim-backend-pool"
    fqdns = [replace(azurerm_api_management.poc_apim.gateway_url, "https://", "")]
  }

  # Backend settings always use HTTPS to communicate with APIM
  backend_http_settings {
    name                                 = "apim-backend-settings"
    protocol                             = "Https"
    port                                 = 443
    cookie_based_affinity                = "Disabled"
    request_timeout                      = 30
    pick_host_name_from_backend_address = true
  }

  # SSL certificate: only created when certificate_pfx_path is provided
  dynamic "ssl_certificate" {
    for_each = var.certificate_pfx_path != "" ? [1] : []
    content {
      name     = "appgw-ssl-cert"
      data     = filebase64(var.certificate_pfx_path)
      password = var.certificate_password
    }
  }

  # HTTP/HTTPS listener: protocol and certificate configured conditionally
  http_listener {
    name                           = "appgw-frontend-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "appgw-frontend-port"
    protocol                       = var.certificate_pfx_path != "" ? "Https" : "Http"
    ssl_certificate_name           = var.certificate_pfx_path != "" ? "appgw-ssl-cert" : null
  }

  # Routing rule: directs traffic to the backend pool
  request_routing_rule {
    name                       = "apim-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-frontend-listener"
    backend_address_pool_name  = "apim-backend-pool"
    backend_http_settings_name = "apim-backend-settings"
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
}

# Diagnostics for APIM
resource "azurerm_monitor_diagnostic_setting" "apim_diagnostics" {
  name                       = "apim-to-loganalytics"
  target_resource_id         = azurerm_api_management.poc_apim.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.poc_workspace.id

  log {
    category = "GatewayLogs"
    enabled  = true
  }

  log {
    category = "GatewayRequests"
    enabled  = true
  }

  log {
    category = "AuditLogs"
    enabled  = true
  }
}

# Diagnostics for App Gateway
resource "azurerm_monitor_diagnostic_setting" "appgw_diagnostics" {
  name                       = "appgw-to-loganalytics"
  target_resource_id         = azurerm_application_gateway.poc_appgw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.poc_workspace.id

  log {
    category = "ApplicationGatewayAccessLog"
    enabled  = true
  }

  log {
    category = "ApplicationGatewayPerformanceLog"
    enabled  = true
  }

  log {
    category = "ApplicationGatewayFirewallLog"
    enabled  = true
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Outputs
output "resource_group_name" {
  description = "Name of the created Resource Group"
  value       = azurerm_resource_group.poc_rg.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.poc_apim.gateway_url
}

output "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.poc_workspace.id
}

output "api_url" {
  description = "Full URL of the sample API"
  value       = "${azurerm_api_management.poc_apim.gateway_url}/${azurerm_api_management_api.poc_api.path}"
}
