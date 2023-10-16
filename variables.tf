variable "name" {
  description = "A name which will be pre-pended to the resources created"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to deploy the service into"
  type        = string
}

variable "app_version" {
  description = "App version to use. This variable facilitates dev flow, the modules may not work with anything other than the default value."
  type        = string
  default     = "3.8.0"
}

variable "subnet_id" {
  description = "The subnet id to deploy the service into"
  type        = string
}

variable "vm_sku" {
  description = "The instance type to use"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_instance_count" {
  description = "The instance count to use"
  type        = number
  default     = 1
}

variable "associate_public_ip_address" {
  description = "Whether to assign a public ip address to this instance"
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "The SSH public key attached for access to the servers"
  type        = string
}

variable "ssh_ip_allowlist" {
  description = "The comma-seperated list of CIDR ranges to allow SSH traffic from"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "The tags to append to this resource"
  default     = {}
  type        = map(string)
}

variable "java_opts" {
  description = "Custom JAVA Options"
  default     = "-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75"
  type        = string
}

# --- Configuration options

variable "raw_topic_name" {
  description = "The name of the raw Kafka topic that enrichment will pull data from"
  type        = string
}

variable "raw_topic_kafka_username" {
  description = "Username for connection to Kafka cluster under PlainLoginModule (default: '$ConnectionString' which is used for EventHubs)"
  type        = string
  default     = "$ConnectionString"
}

variable "raw_topic_kafka_password" {
  description = "Password for connection to Kafka cluster under PlainLoginModule (note: as default the EventHubs topic connection string for reading is expected)"
  type        = string
}

variable "good_topic_name" {
  description = "The name of the good Kafka topic that enrichment will insert good data into"
  type        = string
}

variable "good_topic_kafka_username" {
  description = "Username for connection to Kafka cluster under PlainLoginModule (default: '$ConnectionString' which is used for EventHubs)"
  type        = string
  default     = "$ConnectionString"
}

variable "good_topic_kafka_password" {
  description = "Password for connection to Kafka cluster under PlainLoginModule (note: as default the EventHubs topic connection string for writing is expected)"
  type        = string
}

variable "bad_topic_name" {
  description = "The name of the bad Kafka topic that enrichment will insert failed data into"
  type        = string
}

variable "bad_topic_kafka_username" {
  description = "Username for connection to Kafka cluster under PlainLoginModule (default: '$ConnectionString' which is used for EventHubs)"
  type        = string
  default     = "$ConnectionString"
}

variable "bad_topic_kafka_password" {
  description = "Password for connection to Kafka cluster under PlainLoginModule (note: as default the EventHubs topic connection string for writing is expected)"
  type        = string
}

variable "eh_namespace_name" {
  description = "The name of the Event Hubs namespace (note: if you are not using EventHubs leave this blank)"
  type        = string
  default     = ""
}

variable "kafka_brokers" {
  description = "The brokers to configure for access to the Kafka Cluster (note: as default the EventHubs namespace broker)"
  type        = string
}

variable "assets_update_period" {
  description = "Period after which enrich assets should be checked for updates (e.g. MaxMind DB)"
  default     = "7 days"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.assets_update_period))
    error_message = "Invalid period formant."
  }
}

# --- Enrichment options
#
# To take full advantage of Snowplows enrichments should be activated to enhance and extend the data included
# with each event passing through the pipeline.  By default this module deploys the following:
#
# - campaign_attribution
# - event_fingerprint_config
# - referer_parser
# - ua_parser_config
# - yauaa_enrichment_config
#
# You can override the configuration JSON for any of these auto-enabled enrichments to turn them off or change the parameters
# along with activating any of available enrichments in our estate by passing in the appropriate configuration JSON.
#
# enrichment_yauaa_enrichment_config = <<EOF
# {
#   "schema": "iglu:com.snowplowanalytics.snowplow.enrichments/yauaa_enrichment_config/jsonschema/1-0-0",
#   "data": {
#     "enabled": false,
#     "vendor": "com.snowplowanalytics.snowplow.enrichments",
#     "name": "yauaa_enrichment_config"
#   }
# }
# EOF

variable "custom_tcp_egress_port_list" {
  description = "For opening up TCP ports to access other destinations not served over HTTP(s) (e.g. for SQL / API enrichments)"
  default     = []
  type = list(object({
    priority = number
    port     = number
  }))
}

# --- Iglu Resolver

variable "default_iglu_resolvers" {
  description = "The default Iglu Resolvers that will be used by Enrichment to resolve and validate events"
  default = [
    {
      name            = "Iglu Central"
      priority        = 10
      uri             = "http://iglucentral.com"
      api_key         = ""
      vendor_prefixes = []
    },
    {
      name            = "Iglu Central - Mirror 01"
      priority        = 20
      uri             = "http://mirror01.iglucentral.com"
      api_key         = ""
      vendor_prefixes = []
    }
  ]
  type = list(object({
    name            = string
    priority        = number
    uri             = string
    api_key         = string
    vendor_prefixes = list(string)
  }))
}

variable "custom_iglu_resolvers" {
  description = "The custom Iglu Resolvers that will be used by Enrichment to resolve and validate events"
  default     = []
  type = list(object({
    name            = string
    priority        = number
    uri             = string
    api_key         = string
    vendor_prefixes = list(string)
  }))
}

# --- Enrichments which are enabled by default

variable "enrichment_campaign_attribution" {
  default = ""
  type    = string
}

variable "enrichment_event_fingerprint_config" {
  default = ""
  type    = string
}

variable "enrichment_referer_parser" {
  default = ""
  type    = string
}

variable "enrichment_ua_parser_config" {
  default = ""
  type    = string
}

variable "enrichment_yauaa_enrichment_config" {
  default = ""
  type    = string
}

# --- Enrichments which are disabled by default

variable "enrichment_anon_ip" {
  default = ""
  type    = string
}

variable "enrichment_api_request_enrichment_config" {
  default = ""
  type    = string
}

variable "enrichment_cookie_extractor_config" {
  default = ""
  type    = string
}

variable "enrichment_currency_conversion_config" {
  default = ""
  type    = string
}

variable "enrichment_http_header_extractor_config" {
  default = ""
  type    = string
}

# Note: Requires paid database to function
variable "enrichment_iab_spiders_and_bots_enrichment" {
  default = ""
  type    = string
}

# Note: Requires free or paid subscription to database to function
variable "enrichment_ip_lookups" {
  default = ""
  type    = string
}

variable "enrichment_javascript_script_config" {
  default = ""
  type    = string
}

variable "enrichment_pii_enrichment_config" {
  default = ""
  type    = string
}

variable "enrichment_sql_query_enrichment_config" {
  default = ""
  type    = string
}

variable "enrichment_weather_enrichment_config" {
  default = ""
  type    = string
}

# --- Telemetry

variable "kafka_source" {
  description = "The source providing the Kafka connectivity (def: azure_event_hubs)"
  default     = "azure_event_hubs"
  type        = string
}

variable "telemetry_enabled" {
  description = "Whether or not to send telemetry information back to Snowplow Analytics Ltd"
  type        = bool
  default     = true
}

variable "user_provided_id" {
  description = "An optional unique identifier to identify the telemetry events emitted by this stack"
  type        = string
  default     = ""
}
