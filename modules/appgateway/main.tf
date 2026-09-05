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
  http_listener_name = "httplst-80"
  routing_rule_name  = "rule-http"
  url_path_map_name  = "urlpm-apps"

  backends = {
    django_todo = {
      pool_name    = "beap-django-todo"
      http_name    = "behttp-django-todo"
      probe_name   = "probe-django-todo"
      fqdn         = var.django_todo_backend_fqdn
      health_path  = var.django_todo_health_path
      path_pattern = var.django_todo_path_pattern
    }
    cosmos_crud = {
      pool_name    = "beap-cosmos-crud"
      http_name    = "behttp-cosmos-crud"
      probe_name   = "probe-cosmos-crud"
      fqdn         = var.cosmos_crud_backend_fqdn
      health_path  = var.cosmos_crud_health_path
      path_pattern = var.cosmos_crud_path_pattern
    }
  }
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
    public_ip_address_id = var.public_ip_id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  dynamic "backend_address_pool" {
    for_each = local.backends
    content {
      name  = backend_address_pool.value.pool_name
      fqdns = [backend_address_pool.value.fqdn]
    }
  }

  dynamic "probe" {
    for_each = local.backends
    content {
      name                                      = probe.value.probe_name
      protocol                                  = "Https"
      path                                      = probe.value.health_path
      host                                      = probe.value.fqdn
      interval                                  = 30
      timeout                                   = 30
      unhealthy_threshold                       = 3
      pick_host_name_from_backend_http_settings = false
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.backends
    content {
      name                  = backend_http_settings.value.http_name
      cookie_based_affinity = "Disabled"
      port                  = 443
      protocol              = "Https"
      request_timeout       = 30
      host_name             = backend_http_settings.value.fqdn
      probe_name            = backend_http_settings.value.probe_name
    }
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.backends.django_todo.pool_name
    default_backend_http_settings_name = local.backends.django_todo.http_name

    dynamic "path_rule" {
      for_each = local.backends
      content {
        name                       = "pathrule-${path_rule.key}"
        paths                      = [path_rule.value.path_pattern]
        backend_address_pool_name  = path_rule.value.pool_name
        backend_http_settings_name = path_rule.value.http_name
      }
    }
  }

  request_routing_rule {
    name               = local.routing_rule_name
    rule_type          = "PathBasedRouting"
    priority           = 100
    http_listener_name = local.http_listener_name
    url_path_map_name  = local.url_path_map_name
  }

  # NOTE: HTTP (port 80) only, so the stack is deployable out of the box. For
  # production, add a port 443 frontend_port + http_listener with an
  # ssl_certificate block (ideally Key Vault-backed via an identity{} block),
  # and either redirect port 80 -> 443 or remove the HTTP listener.
}
