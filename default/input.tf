# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "input" {
  description = "configuration paramenter for the service, defined through schema.tf"
  type = object({
    tenancy      = string,
    class        = string,
    owner        = string,
    organization = string,
    solution     = string,
    repository   = string,
    stage        = string,
    region       = string,
    osn          = string,
    adb          = string
  })
}

variable "resolve" {
  description = "configuration paramenter for the service, defined through schema.tf"
  type = object({
    topologies = list(string),
    domains    = list(any),
    wallets    = list(any),
    segments   = list(any)
  })
}

locals {
  # Input Parameter
  adb            = jsondecode(file("${path.module}/database/adb.json"))
  channels       = jsondecode(templatefile("${path.module}/resident/channels.json", {owner = var.input.owner}))
  controls       = jsondecode(file("${path.module}/resident/controls.json"))
  classification = jsondecode(file("${path.module}/resident/classification.json"))
  destinations   = jsondecode(file("${path.module}/network/destinations.json"))
  firewalls      = jsondecode(file("${path.module}/network/firewalls.json"))
  lifecycle      = jsondecode(file("${path.module}/resident/lifecycle.json"))
  profiles       = jsondecode(file("${path.module}/network/profiles.json"))
  rfc6335        = jsondecode(file("${path.module}/network/rfc6335.json"))
  roles          = jsondecode(templatefile("${path.module}/resident/roles.json", {service = local.service_name}))
  routers        = jsondecode(file("${path.module}/network/routers.json"))
  signatures     = jsondecode(file("${path.module}/encryption/signatures.json"))
  secrets        = jsondecode(file("${path.module}/encryption/secrets.json"))
  sections       = jsondecode(file("${path.module}/network/sections.json"))
  sources        = jsondecode(file("${path.module}/network/sources.json"))
  subnets        = jsondecode(file("${path.module}/network/subnets.json"))
  tags           = jsondecode(file("${path.module}/resident/tags.json"))

  #application_profiles = [for firewall, traffic in local.port_filter: traffic]
  database = {
    APEX           = "APEX"
    DATA_WAREHOUSE = "DW"
    JSON           = "ADJ"
    TRANSACTION_PROCESSING = "OLTP"
  }
  defined_routes = {for segment in var.resolve.segments : segment.name => {
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
    "owner"     = var.input.owner
    "lifecycle" = var.input.stage
    "class"     = var.input.class
  }
  group_map = zipmap(
    flatten("${var.resolve.domains[*].roles}"),
    flatten([for domain in var.resolve.domains : [for role in domain.roles : "${local.service_name}_${domain.name}_compartment"]])
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
    }if firewall.outgoing == destination.name}
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
  service_name  = lower("${var.input.organization}_${var.input.solution}_${var.input.stage}")
  service_label = format(
    "%s%s%s", 
    lower(substr(var.input.organization, 0, 3)), 
    lower(substr(var.input.solution, 0, 2)),
    lower(substr(var.input.stage, 0, 3)),
  )
  subnet_cidr = {for segment in var.resolve.segments : segment.name => zipmap(
    keys(local.subnet_newbits[segment.name]),
    flatten(cidrsubnets(segment.cidr, values(local.subnet_newbits[segment.name])...))
  )}
  subnet_newbits = {for segment in var.resolve.segments : segment.name => zipmap(
    [for subnet in local.subnets : subnet.name if contains(var.resolve.topologies, subnet.topology)],
    [for subnet in local.subnets : subnet.newbits if contains(var.resolve.topologies, subnet.topology)]
  )}
  # Merge tags with with the respective namespace information
  tag_map = zipmap(
    flatten([for tag in local.controls[*].tags : tag]),
    flatten([for control in local.controls : [for tag in control.tags : "${local.service_name}_${control.name}"]])
  ) 
  tag_namespaces = {for namespace in local.controls : "${local.service_name}_${namespace.name}" => namespace.stage} 
  vcn_list   = var.resolve.segments[*].name
  zones = {for segment in var.resolve.segments : segment.name => merge(
    local.defined_routes[segment.name],
    local.sections[segment.name],
    local.subnet_cidr[segment.name]
  )}
}