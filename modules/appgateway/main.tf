resource "azurerm_public_ip" "this" {
  name                = "pip-appgw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "this" {
  count               = var.enable_waf ? 1 : 0
  name                = "waf-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

locals {
  sku_name           = var.enable_waf ? "WAF_v2" : "Standard_v2"
  frontend_ip_name   = "feip-public"
  frontend_port_name = "feport-80"
  gateway_ip_config  = "gwip-${var.name_prefix}"
  backend_pool_name  = "beap-containerapp"
  backend_http_name  = "behttp-containerapp"
  probe_name         = "probe-containerapp"
  http_listener_name = "httplst-80"
  routing_rule_name  = "rule-http"
}

resource "azurerm_application_gateway" "this" {
  name                = "agw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  firewall_policy_id = var.enable_waf ? azurerm_web_application_firewall_policy.this[0].id : null

  sku {
    name = local.sku_name
    tier = local.sku_name
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_config
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.this.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  backend_address_pool {
    name  = local.backend_pool_name
    fqdns = [var.backend_fqdn]
  }

  probe {
    name                                      = local.probe_name
    protocol                                  = "Https"
    path                                      = "/"
    host                                      = var.backend_fqdn
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
  }

  backend_http_settings {
    name                  = local.backend_http_name
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 30
    host_name             = var.backend_fqdn
    probe_name            = local.probe_name
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.routing_rule_name
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = local.http_listener_name
    backend_address_pool_name  = local.backend_pool_name
    backend_http_settings_name = local.backend_http_name
  }

  # NOTE: HTTP (port 80) only, so the stack is deployable out of the box. For
  # production, add a port 443 frontend_port + http_listener with an
  # ssl_certificate block (ideally Key Vault-backed via an identity{} block),
  # and either redirect port 80 -> 443 or remove the HTTP listener.
}
