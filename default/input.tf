# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "account" {
  description = "retrieved tenancy data"
  type = object({
    tenancy_id     = string,
    compartment_id = string,
    home           = string,
    user_id        = string
  })
}

variable "settings" {
  description = "configuration paramenter for the service, defined through schema.tf"
  type = object({
    topologies = list(string),
    domains    = list(any),
    segments   = list(any)
  })
}

variable "options" {
  description = "configuration paramenter for the service, defined through schema.tf"
  type = object({
    adb          = string,
    budget       = number,
    class        = string,
    encrypt      = bool,
    name         = string,
    owner        = string,
    organization = string,
    osn          = string,
    region       = string,
    repository   = string,
    stage        = string,
    tenancy      = string,
    wallet       = string
  })
}

locals {
  # General Settings
  rfc6335        = jsondecode(file("${path.module}/../library/rfc6335.json"))
  backup         = jsondecode(file("${path.module}/../library/backup.json"))
  classification = jsondecode(file("${path.module}/../library/classification.json"))
  /*
  policies       = jsondecode(templatefile("${path.module}/../library/policies.json", {
    resident     = oci_identity_compartment.resident.name,
    application  = "${oci_identity_compartment.resident.name}_application_compartment",
    network      = "${oci_identity_compartment.resident.name}_network_compartment",
    database     = "${oci_identity_compartment.resident.name}_database_compartment",
    session_username = var.account.user_id,
    tenancy_OCID = var.tenancy.id,
    #image_OCID   = "${local.service_name}_image_OCID",
    #vault_OCID   = "${local.service_name}_vault_OCID",
    #key_OCID     = "${local.service_name}_key_OCID",
    #stream_OCID  = "${local.service_name}_stream_OCID",
    #workspace_OCID = "${local.service_name}_workspace_OCID",
  }))
  */
  # Service Settings
  alerts         = jsondecode(file("${path.module}/resident/alerts.json"))
  budgets        = jsondecode(templatefile("${path.module}/resident/budgets.json", {user = var.account.user_id}))
  channels       = jsondecode(templatefile("${path.module}/resident/channels.json", {owner = var.options.owner}))
  controls       = jsondecode(templatefile("${path.module}/resident/controls.json", {date = timestamp()}))
  operators      = jsondecode(templatefile("${path.module}/resident/operators.json", {service = local.service_name}))
  periods        = jsondecode(file("${path.module}/resident/periods.json"))
  # Network Settings
  destinations   = jsondecode(file("${path.module}/network/destinations.json"))
  firewalls      = jsondecode(file("${path.module}/network/firewalls.json"))
  profiles       = jsondecode(file("${path.module}/network/profiles.json"))
  routers        = jsondecode(file("${path.module}/network/routers.json"))
  sections       = jsondecode(file("${path.module}/network/sections.json"))
  sources        = jsondecode(file("${path.module}/network/sources.json"))
  subnets        = jsondecode(file("${path.module}/network/subnets.json"))
  # Database Settings
  adb_types      = jsondecode(file("${path.module}/database/adb.json"))
  adb_sizes      = jsondecode(file("${path.module}/database/sizes.json"))
  # Encryption Settings
  signatures     = jsondecode(file("${path.module}/encryption/signatures.json"))
  secrets        = jsondecode(file("${path.module}/encryption/secrets.json"))
  wallets        = jsondecode(file("${path.module}/encryption/wallets.json"))
  # Storage Settings
  buckets        = jsondecode(file("${path.module}/storage/buckets.json"))
  backups        = jsondecode(file("${path.module}/storage/backups.json"))

  # Local variables
  defined_routes = {for segment in var.settings.segments : segment.name => {
    "cpe"      = length(keys(local.router_map)) != 0 ? try(local.router_map[segment.name].cpe,local.router_map["default"].cpe) : null
    "anywhere" = length(keys(local.router_map)) != 0 ? try(local.router_map[segment.name].anywhere,local.router_map["default"].anywhere) : null
    "vcn"      = segment.cidr
    "osn"      = local.osn_cidrs.all
    "buckets"  = local.osn_cidrs.storage
  }}
  destination_map = {for destination in local.destinations : destination.name => {
    gateway = destination.gateway
    name    = destination.name
    zones   = destination.zones
  }if contains(flatten(distinct(flatten(local.firewalls[*].outgoing))), destination.name)}
  freeform_tags = {
    "framework" = "ocloud"
    "owner"     = var.options.owner
    "lifecycle" = var.options.stage
    "class"     = var.options.class
  }
  group_map = zipmap(
    flatten("${var.settings.domains[*].operators}"),
    flatten([for domain in var.settings.domains : [for operator in domain.operators : "${local.service_name}_${domain.name}_compartment"]])
  )
  ports = concat(local.rfc6335, local.profiles)
  port_map = {for firewall in local.firewalls : firewall.name => flatten(distinct(flatten([for zone in firewall.incoming : local.sources[zone]])))}
  port_filter = {for firewall in local.firewalls: firewall.name => {
    name    = firewall.name
    subnets = flatten(matchkeys(local.subnets[*].name, local.subnets[*].firewall, [firewall.name]))
    egress = {for destination in local.destinations : destination.name => {
      gateway = destination.gateway
      name    = destination.name
      zones   = destination.zones
    }if contains(firewall.outgoing, destination.name)}
    ingress = flatten(distinct(flatten([for zone in firewall.incoming : [for profile in local.sources[zone]: [for port in local.ports : {
      description = port.description
      firewall    = firewall.name
      min         = port.min
      max         = port.max
      port        = port.name
      transport   = port.transport
      protocol    = port.protocol
      stateless   = port.stateless
      zone        = zone
    }if profile == port.name]]])))
  }}
  router_map = {for router in local.routers : router.name => {
    name     = router.name
    cpe      = router.cpe
    anywhere = router.anywhere
  }}
  route_rules = transpose({
    for destination in local.destinations : destination.name => destination.zones
    if contains(flatten(distinct(flatten(local.firewalls[*].outgoing))), destination.name)
  })
  # Computed Parameter
  service_name  = lower("${var.options.organization}_${var.options.name}_${var.options.stage}")
  service_label = format(
    "%s%s%s", 
    lower(substr(var.options.organization, 0, 3)), 
    lower(substr(var.options.name, 0, 2)),
    lower(substr(var.options.stage, 0, 3)),
  )
  subnet_cidr = {for segment in var.settings.segments : segment.name => zipmap(
    keys(local.subnet_newbits[segment.name]),
    flatten(cidrsubnets(segment.cidr, values(local.subnet_newbits[segment.name])...))
  )}
  subnet_newbits = {for segment in var.settings.segments : segment.name => zipmap(
    [for subnet in local.subnets : subnet.name if contains(var.settings.topologies, subnet.topology)],
    [for subnet in local.subnets : subnet.newbits if contains(var.settings.topologies, subnet.topology)]
  )}
  vcn_list   = var.settings.segments[*].name
  zones = {for segment in var.settings.segments : segment.name => merge(
    local.defined_routes[segment.name],
    local.sections[segment.name],
    local.subnet_cidr[segment.name]
  )}
}