[![Release][release-image]][release] [![CI][ci-image]][ci] [![License][license-image]][license] [![Registry][registry-image]][registry] [![Source][source-image]][source]

# terraform-azurerm-enrich-event-hub-vmss

A Terraform module which deploys Snowplow Enrich service on VMSS.

## Telemetry

This module by default collects and forwards telemetry information to Snowplow to understand how our applications are being used.  No identifying information about your sub-account or account fingerprints are ever forwarded to us - it is very simple information about what modules and applications are deployed and active.

If you wish to subscribe to our mailing list for updates to these modules or security advisories please set the `user_provided_id` variable to include a valid email address which we can reach you at.

### How do I disable it?

To disable telemetry simply set variable `telemetry_enabled = false`.

### What are you collecting?

For details on what information is collected please see this module: https://github.com/snowplow-devops/terraform-snowplow-telemetry

## Usage

### Standard usage

Enrich takes data from a raw input topic and pushes validated data to the enriched topic and failed data to the bad topic.  As part of this validation process we leverage Iglu which is Snowplow's schema repository - the home for event and entity definitions.  If you are using custom events that you have defined yourself you will need to ensure that you link in your own Iglu Registries to this module so that they can be discovered correctly.

By default this module enables 5 enrichments which you can find in the `templates/enrichments` directory of this module.

```hcl
module "pipeline_eh_namespace" {
  source  = "snowplow-devops/event-hub-namespace/azurerm"
  version = "0.1.1"

  name                = "snowplow-pipeline"
  resource_group_name = var.resource_group_name
}

module "raw_eh_topic" {
  source  = "snowplow-devops/event-hub/azurerm"
  version = "0.1.1"

  name                = "raw-topic"
  namespace_name      = module.pipeline_eh_namespace.name
  resource_group_name = var.resource_group_name
}

module "bad_1_eh_topic" {
  source  = "snowplow-devops/event-hub/azurerm"
  version = "0.1.1"

  name                = "bad-1-topic"
  namespace_name      = module.pipeline_eh_namespace.name
  resource_group_name = var.resource_group_name
}

module "enriched_eh_topic" {
  source  = "snowplow-devops/event-hub/azurerm"
  version = "0.1.1"

  name                = "enriched-topic"
  namespace_name      = module.pipeline_eh_namespace.name
  resource_group_name = var.resource_group_name
}

module "enrich_event_hub" {
  source = "snowplow-devops/enrich-event-hub-vmss/azurerm"

  accept_limited_use_license = true

  name                = "enrich-server"
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id_for_servers
  
  raw_topic_name            = module.raw_eh_topic.name
  raw_topic_kafka_password  = module.raw_eh_topic.read_only_primary_connection_string
  good_topic_name           = module.enriched_eh_topic.name
  good_topic_kafka_password = module.enriched_eh_topic.read_write_primary_connection_string
  bad_topic_name            = module.bad_1_eh_topic.name
  bad_topic_kafka_password  = module.bad_1_eh_topic.read_write_primary_connection_string
  eh_namespace_name         = module.pipeline_eh_namespace.name
  kafka_brokers             = module.pipeline_eh_namespace.broker

  ssh_public_key   = "your-public-key-here"
  ssh_ip_allowlist = ["0.0.0.0/0"]

  # Linking in the custom Iglu Server here
  custom_iglu_resolvers = [
    {
      name            = "Iglu Server"
      priority        = 0
      uri             = "http://your-iglu-server-endpoint/api"
      api_key         = var.iglu_super_api_key
      vendor_prefixes = []
    }
  ]
}
```

### Inserting custom enrichments

To define your own enrichment configurations you will need to provide a JSON encoded string of the enrichment in the appropriate placeholder.

```hcl
locals {
  enrichment_anon_ip = jsonencode(<<EOF
{
  "schema": "iglu:com.snowplowanalytics.snowplow/anon_ip/jsonschema/1-0-1",
  "data": {
    "name": "anon_ip",
    "vendor": "com.snowplowanalytics.snowplow",
    "enabled": true,
    "parameters": {
      "anonOctets": 1,
      "anonSegments": 1
    }
  }
}
EOF
  )
}

module "enrich_event_hub" {
  source = "snowplow-devops/enrich-event-hub-vmss/azurerm"

  accept_limited_use_license = true

  name                = "enrich-server"
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id_for_servers
  
  raw_topic_name            = module.raw_eh_topic.name
  raw_topic_kafka_password  = module.raw_eh_topic.read_only_primary_connection_string
  good_topic_name           = module.enriched_eh_topic.name
  good_topic_kafka_password = module.enriched_eh_topic.read_write_primary_connection_string
  bad_topic_name            = module.bad_1_eh_topic.name
  bad_topic_kafka_password  = module.bad_1_eh_topic.read_write_primary_connection_string
  eh_namespace_name         = module.pipeline_eh_namespace.name
  kafka_brokers             = module.pipeline_eh_namespace.broker

  ssh_public_key   = "your-public-key-here"
  ssh_ip_allowlist = ["0.0.0.0/0"]

  # Linking in the custom Iglu Server here
  custom_iglu_resolvers = [
    {
      name            = "Iglu Server"
      priority        = 0
      uri             = "http://your-iglu-server-endpoint/api"
      api_key         = var.iglu_super_api_key
      vendor_prefixes = []
    }
  ]

  # Enable this enrichment
  enrichment_anon_ip = local.enrichment_anon_ip
}
```

### Disabling default enrichments

As with inserting custom enrichments to disable the default enrichments a similar strategy must be employed.  For example to disable YAUAA you would do the following.

```hcl
locals {
  enrichment_yauaa = jsonencode(<<EOF
{
  "schema": "iglu:com.snowplowanalytics.snowplow.enrichments/yauaa_enrichment_config/jsonschema/1-0-0",
  "data": {
    "enabled": false,
    "vendor": "com.snowplowanalytics.snowplow.enrichments",
    "name": "yauaa_enrichment_config"
  }
}
EOF
  )
}

module "enrich_event_hub" {
  source = "snowplow-devops/enrich-event-hub-vmss/azurerm"

  accept_limited_use_license = true

  name                = "enrich-server"
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id_for_servers
  
  raw_topic_name            = module.raw_eh_topic.name
  raw_topic_kafka_password  = module.raw_eh_topic.read_only_primary_connection_string
  good_topic_name           = module.enriched_eh_topic.name
  good_topic_kafka_password = module.enriched_eh_topic.read_write_primary_connection_string
  bad_topic_name            = module.bad_1_eh_topic.name
  bad_topic_kafka_password  = module.bad_1_eh_topic.read_write_primary_connection_string
  eh_namespace_name         = module.pipeline_eh_namespace.name
  kafka_brokers             = module.pipeline_eh_namespace.broker

  ssh_public_key   = "your-public-key-here"
  ssh_ip_allowlist = ["0.0.0.0/0"]

  # Linking in the custom Iglu Server here
  custom_iglu_resolvers = [
    {
      name            = "Iglu Server"
      priority        = 0
      uri             = "http://your-iglu-server-endpoint/api"
      api_key         = var.iglu_super_api_key
      vendor_prefixes = []
    }
  ]

  # Disable this enrichment
  enrichment_yauaa_enrichment_config = local.enrichment_yauaa
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.58.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.58.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_service"></a> [service](#module\_service) | snowplow-devops/service-vmss/azurerm | 0.1.1 |
| <a name="module_telemetry"></a> [telemetry](#module\_telemetry) | snowplow-devops/telemetry/snowplow | 0.5.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_eventhub_consumer_group.raw_topic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/eventhub_consumer_group) | resource |
| [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.egress_tcp_443](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.egress_tcp_80](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.egress_tcp_custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.egress_udp_123](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.ingress_tcp_22](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bad_topic_kafka_password"></a> [bad\_topic\_kafka\_password](#input\_bad\_topic\_kafka\_password) | Password for connection to Kafka cluster under PlainLoginModule (note: as default the EventHubs topic connection string for writing is expected) | `string` | n/a | yes |
| <a name="input_bad_topic_name"></a> [bad\_topic\_name](#input\_bad\_topic\_name) | The name of the bad Kafka topic that enrichment will insert failed data into | `string` | n/a | yes |
| <a name="input_good_topic_kafka_password"></a> [good\_topic\_kafka\_password](#input\_good\_topic\_kafka\_password) | Password for connection to Kafka cluster under PlainLoginModule (note: as default the EventHubs topic connection string for writing is expected) | `string` | n/a | yes |
| <a name="input_good_topic_name"></a> [good\_topic\_name](#input\_good\_topic\_name) | The name of the good Kafka topic that enrichment will insert good data into | `string` | n/a | yes |
| <a name="input_kafka_brokers"></a> [kafka\_brokers](#input\_kafka\_brokers) | The brokers to configure for access to the Kafka Cluster (note: as default the EventHubs namespace broker) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | A name which will be pre-pended to the resources created | `string` | n/a | yes |
| <a name="input_raw_topic_kafka_password"></a> [raw\_topic\_kafka\_password](#input\_raw\_topic\_kafka\_password) | Password for connection to Kafka cluster under PlainLoginModule (note: as default the EventHubs topic connection string for reading is expected) | `string` | n/a | yes |
| <a name="input_raw_topic_name"></a> [raw\_topic\_name](#input\_raw\_topic\_name) | The name of the raw Kafka topic that enrichment will pull data from | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group to deploy the service into | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | The SSH public key attached for access to the servers | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | The subnet id to deploy the service into | `string` | n/a | yes |
| <a name="input_accept_limited_use_license"></a> [accept\_limited\_use\_license](#input\_accept\_limited\_use\_license) | Acceptance of the SLULA terms (https://docs.snowplow.io/limited-use-license-1.0/) | `bool` | `false` | no |
| <a name="input_app_version"></a> [app\_version](#input\_app\_version) | App version to use. This variable facilitates dev flow, the modules may not work with anything other than the default value. | `string` | `"3.9.0"` | no |
| <a name="input_assets_update_period"></a> [assets\_update\_period](#input\_assets\_update\_period) | Period after which enrich assets should be checked for updates (e.g. MaxMind DB) | `string` | `"7 days"` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether to assign a public ip address to this instance | `bool` | `true` | no |
| <a name="input_bad_topic_kafka_username"></a> [bad\_topic\_kafka\_username](#input\_bad\_topic\_kafka\_username) | Username for connection to Kafka cluster under PlainLoginModule (default: '$ConnectionString' which is used for EventHubs) | `string` | `"$ConnectionString"` | no |
| <a name="input_custom_iglu_resolvers"></a> [custom\_iglu\_resolvers](#input\_custom\_iglu\_resolvers) | The custom Iglu Resolvers that will be used by Enrichment to resolve and validate events | <pre>list(object({<br>    name            = string<br>    priority        = number<br>    uri             = string<br>    api_key         = string<br>    vendor_prefixes = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_custom_tcp_egress_port_list"></a> [custom\_tcp\_egress\_port\_list](#input\_custom\_tcp\_egress\_port\_list) | For opening up TCP ports to access other destinations not served over HTTP(s) (e.g. for SQL / API enrichments) | <pre>list(object({<br>    priority = number<br>    port     = number<br>  }))</pre> | `[]` | no |
| <a name="input_default_iglu_resolvers"></a> [default\_iglu\_resolvers](#input\_default\_iglu\_resolvers) | The default Iglu Resolvers that will be used by Enrichment to resolve and validate events | <pre>list(object({<br>    name            = string<br>    priority        = number<br>    uri             = string<br>    api_key         = string<br>    vendor_prefixes = list(string)<br>  }))</pre> | <pre>[<br>  {<br>    "api_key": "",<br>    "name": "Iglu Central",<br>    "priority": 10,<br>    "uri": "http://iglucentral.com",<br>    "vendor_prefixes": []<br>  },<br>  {<br>    "api_key": "",<br>    "name": "Iglu Central - Mirror 01",<br>    "priority": 20,<br>    "uri": "http://mirror01.iglucentral.com",<br>    "vendor_prefixes": []<br>  }<br>]</pre> | no |
| <a name="input_eh_namespace_name"></a> [eh\_namespace\_name](#input\_eh\_namespace\_name) | The name of the Event Hubs namespace (note: if you are not using EventHubs leave this blank) | `string` | `""` | no |
| <a name="input_enrichment_anon_ip"></a> [enrichment\_anon\_ip](#input\_enrichment\_anon\_ip) | n/a | `string` | `""` | no |
| <a name="input_enrichment_api_request_enrichment_config"></a> [enrichment\_api\_request\_enrichment\_config](#input\_enrichment\_api\_request\_enrichment\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_campaign_attribution"></a> [enrichment\_campaign\_attribution](#input\_enrichment\_campaign\_attribution) | n/a | `string` | `""` | no |
| <a name="input_enrichment_cookie_extractor_config"></a> [enrichment\_cookie\_extractor\_config](#input\_enrichment\_cookie\_extractor\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_currency_conversion_config"></a> [enrichment\_currency\_conversion\_config](#input\_enrichment\_currency\_conversion\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_event_fingerprint_config"></a> [enrichment\_event\_fingerprint\_config](#input\_enrichment\_event\_fingerprint\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_http_header_extractor_config"></a> [enrichment\_http\_header\_extractor\_config](#input\_enrichment\_http\_header\_extractor\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_iab_spiders_and_bots_enrichment"></a> [enrichment\_iab\_spiders\_and\_bots\_enrichment](#input\_enrichment\_iab\_spiders\_and\_bots\_enrichment) | Note: Requires paid database to function | `string` | `""` | no |
| <a name="input_enrichment_ip_lookups"></a> [enrichment\_ip\_lookups](#input\_enrichment\_ip\_lookups) | Note: Requires free or paid subscription to database to function | `string` | `""` | no |
| <a name="input_enrichment_javascript_script_config"></a> [enrichment\_javascript\_script\_config](#input\_enrichment\_javascript\_script\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_pii_enrichment_config"></a> [enrichment\_pii\_enrichment\_config](#input\_enrichment\_pii\_enrichment\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_referer_parser"></a> [enrichment\_referer\_parser](#input\_enrichment\_referer\_parser) | n/a | `string` | `""` | no |
| <a name="input_enrichment_sql_query_enrichment_config"></a> [enrichment\_sql\_query\_enrichment\_config](#input\_enrichment\_sql\_query\_enrichment\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_ua_parser_config"></a> [enrichment\_ua\_parser\_config](#input\_enrichment\_ua\_parser\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_weather_enrichment_config"></a> [enrichment\_weather\_enrichment\_config](#input\_enrichment\_weather\_enrichment\_config) | n/a | `string` | `""` | no |
| <a name="input_enrichment_yauaa_enrichment_config"></a> [enrichment\_yauaa\_enrichment\_config](#input\_enrichment\_yauaa\_enrichment\_config) | n/a | `string` | `""` | no |
| <a name="input_good_topic_kafka_username"></a> [good\_topic\_kafka\_username](#input\_good\_topic\_kafka\_username) | Username for connection to Kafka cluster under PlainLoginModule (default: '$ConnectionString' which is used for EventHubs) | `string` | `"$ConnectionString"` | no |
| <a name="input_java_opts"></a> [java\_opts](#input\_java\_opts) | Custom JAVA Options | `string` | `"-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75"` | no |
| <a name="input_kafka_source"></a> [kafka\_source](#input\_kafka\_source) | The source providing the Kafka connectivity (def: azure\_event\_hubs) | `string` | `"azure_event_hubs"` | no |
| <a name="input_raw_topic_kafka_username"></a> [raw\_topic\_kafka\_username](#input\_raw\_topic\_kafka\_username) | Username for connection to Kafka cluster under PlainLoginModule (default: '$ConnectionString' which is used for EventHubs) | `string` | `"$ConnectionString"` | no |
| <a name="input_ssh_ip_allowlist"></a> [ssh\_ip\_allowlist](#input\_ssh\_ip\_allowlist) | The comma-seperated list of CIDR ranges to allow SSH traffic from | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | The tags to append to this resource | `map(string)` | `{}` | no |
| <a name="input_telemetry_enabled"></a> [telemetry\_enabled](#input\_telemetry\_enabled) | Whether or not to send telemetry information back to Snowplow Analytics Ltd | `bool` | `true` | no |
| <a name="input_user_provided_id"></a> [user\_provided\_id](#input\_user\_provided\_id) | An optional unique identifier to identify the telemetry events emitted by this stack | `string` | `""` | no |
| <a name="input_vm_instance_count"></a> [vm\_instance\_count](#input\_vm\_instance\_count) | The instance count to use | `number` | `1` | no |
| <a name="input_vm_sku"></a> [vm\_sku](#input\_vm\_sku) | The instance type to use | `string` | `"Standard_B2s"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nsg_id"></a> [nsg\_id](#output\_nsg\_id) | ID of the network security group attached to the Collector Server nodes |
| <a name="output_vmss_id"></a> [vmss\_id](#output\_vmss\_id) | ID of the VM scale-set |

# Copyright and license

Copyright 2023-present Snowplow Analytics Ltd.

Licensed under the [Snowplow Limited Use License Agreement][license]. _(If you are uncertain how it applies to your use case, check our answers to [frequently asked questions][license-faq].)_

[release]: https://github.com/snowplow-devops/terraform-azurerm-enrich-event-hub-vmss/releases/latest
[release-image]: https://img.shields.io/github/v/release/snowplow-devops/terraform-azurerm-enrich-event-hub-vmss

[ci]: https://github.com/snowplow-devops/terraform-azurerm-enrich-event-hub-vmss/actions?query=workflow%3Aci
[ci-image]: https://github.com/snowplow-devops/terraform-azurerm-enrich-event-hub-vmss/workflows/ci/badge.svg

[license]: https://docs.snowplow.io/limited-use-license-1.1/
[license-image]: https://img.shields.io/badge/license-Snowplow--Limited--Use-blue.svg?style=flat
[license-faq]: https://docs.snowplow.io/docs/contributing/limited-use-license-faq/

[registry]: https://registry.terraform.io/modules/snowplow-devops/enrich-event-hub-vmss/azurerm/latest
[registry-image]: https://img.shields.io/static/v1?label=Terraform&message=Registry&color=7B42BC&logo=terraform

[source]: https://github.com/snowplow/enrich
[source-image]: https://img.shields.io/static/v1?label=Snowplow&message=Enrich&color=0E9BA4&logo=GitHub
