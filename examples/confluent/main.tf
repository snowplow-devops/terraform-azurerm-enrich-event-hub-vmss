locals {
  name = "enrich-test"

  ssh_public_key   = "PUBLIC_KEY"
  user_provided_id = "enrich-module-example@snowplow.io"

  # This is your cluster "Bootstrap Server"
  kafka_brokers = "<SET_ME>"
  # This is your cluster API Key (Key + Secret)
  kafka_username = "<SET_ME>"
  kafka_password = "<SET_ME>"

  # Default names for topics (note: change if you used different denominations)
  raw_topic_name  = "raw"
  good_topic_name = "enriched"
  bad_topic_name  = "bad_1"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = "North Europe"
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

  raw_topic_name            = local.raw_topic_name
  raw_topic_kafka_username  = local.kafka_username
  raw_topic_kafka_password  = local.kafka_password
  good_topic_name           = local.good_topic_name
  good_topic_kafka_username = local.kafka_username
  good_topic_kafka_password = local.kafka_password
  bad_topic_name            = local.bad_topic_name
  bad_topic_kafka_username  = local.kafka_username
  bad_topic_kafka_password  = local.kafka_password
  kafka_brokers             = local.kafka_brokers

  kafka_source = "confluent_cloud"

  ssh_public_key   = local.ssh_public_key
  ssh_ip_allowlist = ["0.0.0.0/0"]

  user_provided_id = local.user_provided_id

  depends_on = [azurerm_resource_group.rg]
}
