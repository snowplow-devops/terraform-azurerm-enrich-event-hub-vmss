locals {
  name = "enrich-test"

  ssh_public_key   = "PUBLIC_KEY"
  user_provided_id = "enrich-module-example@snowplow.io"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = "North Europe"
}

module "pipeline_eh_namespace" {
  source  = "snowplow-devops/event-hub-namespace/azurerm"
  version = "0.1.1"

  name                = "${local.name}-ehn"
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

module "raw_eh_topic" {
  source  = "snowplow-devops/event-hub/azurerm"
  version = "0.1.1"

  name                = "${local.name}-raw"
  namespace_name      = module.pipeline_eh_namespace.name
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

module "bad_1_eh_topic" {
  source  = "snowplow-devops/event-hub/azurerm"
  version = "0.1.1"

  name                = "${local.name}-bad-1"
  namespace_name      = module.pipeline_eh_namespace.name
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

module "enriched_eh_topic" {
  source  = "snowplow-devops/event-hub/azurerm"
  version = "0.1.1"

  name                = "${local.name}-enriched"
  namespace_name      = module.pipeline_eh_namespace.name
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

module "vnet" {
  source  = "snowplow-devops/vnet/azurerm"
  version = "0.1.2"

  name                = "${local.name}-vnet"
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}


module "enrich_service" {
  source = "../.."

  name                = "${local.name}-enrich-server"
  resource_group_name = azurerm_resource_group.rg.name

  subnet_id = lookup(module.vnet.vnet_subnets_name_id, "pipeline1")

  raw_topic_name               = module.raw_eh_topic.name
  raw_topic_connection_string  = module.raw_eh_topic.read_only_primary_connection_string
  good_topic_name              = module.enriched_eh_topic.name
  good_topic_connection_string = module.enriched_eh_topic.read_write_primary_connection_string
  bad_topic_name               = module.bad_1_eh_topic.name
  bad_topic_connection_string  = module.bad_1_eh_topic.read_write_primary_connection_string
  eh_namespace_name            = module.pipeline_eh_namespace.name
  eh_namespace_broker          = module.pipeline_eh_namespace.broker

  ssh_public_key   = local.ssh_public_key
  ssh_ip_allowlist = ["0.0.0.0/0"]

  user_provided_id = local.user_provided_id

  depends_on = [azurerm_resource_group.rg]
}
