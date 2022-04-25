# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "account" {
  description = "retrieved tenancy data"
  type = object({
    tenancy_id     = string,
    class          = string,
    compartment_id = string,
    home           = string,
    user_id        = string
  })
}

variable "resident" {
  description = "configuration paramenter for the service, defined through schema.tf"
  type = object({
    adb          = string,
    budget       = number,
    encrypt      = bool,
    name         = string,
    owner        = string,
    organization = string,
    osn          = string,
    region       = string,
    repository   = string,
    stage        = string,
    topologies   = list(any),
    wallet       = string
  })
}

locals {
  # Libraries
  rfc6335        = jsondecode(file("${path.module}/library/rfc6335.json"))
  /*
  policies       = jsondecode(templatefile("${path.module}/library/policies.json", {
    resident     = oci_identity_compartment.resident.name,
    application  = "${oci_identity_compartment.resident.name}_application_compartment",
    network      = "${oci_identity_compartment.resident.name}_network_compartment",
    database     = "${oci_identity_compartment.resident.name}_database_compartment",
    session_username = var.account.user_id,
    tenancy_OCID = var.account.tenancy_id,
    #image_OCID   = "${local.service_name}_image_OCID",
    #vault_OCID   = "${local.service_name}_vault_OCID",
    #key_OCID     = "${local.service_name}_key_OCID",
    #stream_OCID  = "${local.service_name}_stream_OCID",
    #workspace_OCID = "${local.service_name}_workspace_OCID",
  }))
  */
  # Service Settings
  alerts         = jsondecode(file("${path.module}/service/alerts.json"))
  budgets        = jsondecode(templatefile("${path.module}/service/budgets.json", {user = var.account.user_id}))
  channels       = jsondecode(templatefile("${path.module}/service/channels.json", {owner = var.resident.owner}))
  controls       = jsondecode(templatefile("${path.module}/service/controls.json", {date = timestamp()}))
  domains        = jsondecode(file("${path.module}/service/domains.json"))
  operators      = jsondecode(templatefile("${path.module}/service/operators.json", {service = local.service_name}))
  periods        = jsondecode(file("${path.module}/service/periods.json"))
  # Network Settings
  destinations   = jsondecode(file("${path.module}/network/destinations.json"))
  firewalls      = jsondecode(file("${path.module}/network/firewalls.json"))
  profiles       = jsondecode(file("${path.module}/network/profiles.json"))
  routers        = jsondecode(file("${path.module}/network/routers.json"))
  sections       = jsondecode(file("${path.module}/network/sections.json"))
  segments       = jsondecode(file("${path.module}/network/segments.json"))
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
  defined_routes = {for segment in local.segments : segment.name => {
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
    "owner"     = var.resident.owner
    "lifecycle" = var.resident.stage
    "class"     = var.account.class
  }
  group_map = zipmap(
    flatten("${local.domains[*].operators}"),
    flatten([for domain in local.domains : [for operator in domain.operators : "${local.service_name}_${domain.name}_compartment"]])
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
  region   = {
    key  = local.home_region_key
    name = local.home_region_name
  }
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
  service_name  = lower("${var.resident.organization}_${var.resident.name}_${var.resident.stage}")
  service_label = format(
    "%s%s%s", 
    lower(substr(var.resident.organization, 0, 3)), 
    lower(substr(var.resident.name, 0, 2)),
    lower(substr(var.resident.stage, 0, 3)),
  )
  subnet_cidr = {for segment in local.segments : segment.name => zipmap(
    keys(local.subnet_newbits[segment.name]),
    flatten(cidrsubnets(segment.cidr, values(local.subnet_newbits[segment.name])...))
  )}
  subnet_newbits = {for segment in local.segments : segment.name => zipmap(
    [for subnet in local.subnets : subnet.name if contains(var.resident.topologies, subnet.topology)],
    [for subnet in local.subnets : subnet.newbits if contains(var.resident.topologies, subnet.topology)]
  )}
  vcn_list   = local.segments[*].name
  zones = {for segment in local.segments : segment.name => merge(
    local.defined_routes[segment.name],
    local.sections[segment.name],
    local.subnet_cidr[segment.name]
  )}
}