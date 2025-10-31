locals {
  module_name_suffix = var.kafka_source == "azure_event_hubs" ? "" : ":${var.kafka_source}"

  module_name    = "enrich-event-hub-vmss${local.module_name_suffix}"
  module_version = "0.3.0"

  app_name    = "enrich-kafka"
  app_version = var.app_version

  local_tags = {
    Name           = var.name
    app_name       = local.app_name
    app_version    = local.app_version
    module_name    = local.module_name
    module_version = local.module_version
  }

  tags = merge(
    var.tags,
    local.local_tags
  )
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

module "telemetry" {
  source  = "snowplow-devops/telemetry/snowplow"
  version = "0.5.0"

  count = var.telemetry_enabled ? 1 : 0

  user_provided_id = var.user_provided_id
  cloud            = "AZURE"
  region           = data.azurerm_resource_group.rg.location
  app_name         = local.app_name
  app_version      = local.app_version
  module_name      = local.module_name
  module_version   = local.module_version
}

# --- Network: Security Group Rules

resource "azurerm_network_security_group" "nsg" {
  name                = var.name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name

  tags = local.tags
}

resource "azurerm_network_security_rule" "ingress_tcp_22" {
  name                        = "${var.name}_ingress_tcp_22"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.ssh_ip_allowlist
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "egress_tcp_80" {
  name                        = "${var.name}_egress_tcp_80"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "egress_tcp_443" {
  name                        = "${var.name}_egress_tcp_443"
  priority                    = 101
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Needed for clock synchronization
resource "azurerm_network_security_rule" "egress_udp_123" {
  name                        = "${var.name}_egress_udp_123"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "egress_tcp_custom" {
  for_each = { for _, r in var.custom_tcp_egress_port_list : "p_${r.port}" => r }

  name                        = "${var.name}_egress_tcp_${each.value.port}"
  priority                    = each.value.priority
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# --- EventHubs: Consumer Groups

resource "azurerm_eventhub_consumer_group" "raw_topic" {
  count = var.eh_namespace_name != "" ? 1 : 0

  name = var.name

  namespace_name      = var.eh_namespace_name
  eventhub_name       = var.raw_topic_name
  resource_group_name = var.resource_group_name
}

# --- Compute: VM scale-set deployment

locals {
  hocon = templatefile("${path.module}/templates/config.hocon.tmpl", {
    raw_topic_name            = var.raw_topic_name
    raw_group_id              = coalesce(join("", azurerm_eventhub_consumer_group.raw_topic.*.name), var.name)
    raw_topic_kafka_username  = var.raw_topic_kafka_username
    raw_topic_kafka_password  = var.raw_topic_kafka_password
    good_topic_name           = var.good_topic_name
    good_topic_kafka_username = var.good_topic_kafka_username
    good_topic_kafka_password = var.good_topic_kafka_password
    bad_topic_name            = var.bad_topic_name
    bad_topic_kafka_username  = var.bad_topic_kafka_username
    bad_topic_kafka_password  = var.bad_topic_kafka_password
    kafka_brokers             = var.kafka_brokers

    assets_update_period = var.assets_update_period

    telemetry_disable          = !var.telemetry_enabled
    telemetry_collector_uri    = join("", module.telemetry.*.collector_uri)
    telemetry_collector_port   = 443
    telemetry_secure           = true
    telemetry_user_provided_id = var.user_provided_id
    telemetry_auto_gen_id      = join("", module.telemetry.*.auto_generated_id)
    telemetry_module_name      = local.module_name
    telemetry_module_version   = local.module_version
  })

  user_data = templatefile("${path.module}/templates/user-data.sh.tmpl", {
    accept_limited_use_license = var.accept_limited_use_license

    config_b64        = base64encode(local.hocon)
    version           = local.app_version
    iglu_resolver_b64 = base64encode(local.iglu_resolver)

    telemetry_script = join("", module.telemetry.*.azurerm_ubuntu_22_04_user_data)

    java_opts = var.java_opts

    enrichment_campaign_attribution_b64            = base64encode(local.campaign_attribution)
    enrichment_event_fingerprint_config_b64        = base64encode(local.event_fingerprint_config)
    enrichment_referer_parser_b64                  = base64encode(local.referer_parser)
    enrichment_ua_parser_config_b64                = base64encode(local.ua_parser_config)
    enrichment_yauaa_enrichment_config_b64         = base64encode(local.yauaa_enrichment_config)
    enrichment_anon_ip_b64                         = base64encode(var.enrichment_anon_ip)
    enrichment_api_request_enrichment_config_b64   = base64encode(var.enrichment_api_request_enrichment_config)
    enrichment_cookie_extractor_config_b64         = base64encode(var.enrichment_cookie_extractor_config)
    enrichment_currency_conversion_config_b64      = base64encode(var.enrichment_currency_conversion_config)
    enrichment_http_header_extractor_config_b64    = base64encode(var.enrichment_http_header_extractor_config)
    enrichment_iab_spiders_and_bots_enrichment_b64 = base64encode(var.enrichment_iab_spiders_and_bots_enrichment)
    enrichment_ip_lookups_b64                      = base64encode(var.enrichment_ip_lookups)
    enrichment_javascript_script_config_b64        = base64encode(var.enrichment_javascript_script_config)
    enrichment_pii_enrichment_config_b64           = base64encode(var.enrichment_pii_enrichment_config)
    enrichment_sql_query_enrichment_config_b64     = base64encode(var.enrichment_sql_query_enrichment_config)
    enrichment_weather_enrichment_config_b64       = base64encode(var.enrichment_weather_enrichment_config)
  })
}

module "service" {
  source  = "snowplow-devops/service-vmss/azurerm"
  version = "0.1.1"

  user_supplied_script = local.user_data
  name                 = var.name
  resource_group_name  = var.resource_group_name

  subnet_id                   = var.subnet_id
  network_security_group_id   = azurerm_network_security_group.nsg.id
  associate_public_ip_address = var.associate_public_ip_address
  admin_ssh_public_key        = var.ssh_public_key

  sku            = var.vm_sku
  instance_count = var.vm_instance_count

  tags = local.tags
}
