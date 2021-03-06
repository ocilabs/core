// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "network" { 
  value = {for segment in local.segments : segment.name => {
    name         = segment.name
    region       = var.service.region
    display_name = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}"
    dns_label    = "${var.service.label}${index(local.vcn_list, segment.name) + 1}"
    compartment  = contains(flatten(local.domains[*].name), "network") ? "${var.service.name}_network_compartment" : var.service.name
    stage        = segment.stage
    cidr         = segment.cidr
    gateways = {
      drg = {
        name     = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_router"
        create   = anytrue([contains(local.routers[*].name, segment.name), contains(local.routers[*].name, "default")])
        type     = "VCN"
        cpe      = try(local.router_map[segment.name].cpe, local.router_map["default"].cpe)
        anywhere = try(local.router_map[segment.name].anywhere, local.router_map["default"].anywhere)
      }
      internet   = {
        name     = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_internet"
      }
      nat        = {
        name     = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_translation"
      }
      service    = {
        name     = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_service"
        scope    = var.service.osn == "ALL" ? "osn" : "storage"
        all      = local.osn_cidrs.all
        storage  = local.osn_cidrs.storage
      }
    }
    route_tables = {for subnet in local.subnets : subnet.name => { 
      display_name = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}_table"
      stage        = subnet.stage
      route_rules  = flatten([for destination in local.port_filter[subnet.firewall].egress: [for zone in destination.zones : {
        description = "Routes ${destination.name} traffic via the ${destination.gateway} gateway."
        destination    = matchkeys(values(local.zones[segment.name]), keys(local.zones[segment.name]), [zone])[0]
        destination_type = can(regex(
          "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\/(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", matchkeys(values(local.zones[segment.name]), keys(local.zones[segment.name]), [zone])[0]
        )) ? "CIDR_BLOCK" : "SERVICE_CIDR_BLOCK"
        network_entity = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_${destination.gateway}"
      }]])
    }}
    security_lists = {for subnet in local.subnets : subnet.name => { 
      display_name = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}_filter"
      stage        = subnet.stage
      ingress      = {for profile in local.port_filter[subnet.firewall].ingress: "${profile.firewall}_${profile.zone}_${profile.port}_${profile.transport}" => {
        protocol    = profile.protocol
        description = "Allow incoming tcp ${profile.port} traffic from ${profile.zone} via the ${profile.firewall} port filter"
        source      = matchkeys(values(local.zones[segment.name]), keys(local.zones[segment.name]), [profile.zone])[0]
        source_type = can(regex(
          "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\/(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", matchkeys(values(local.zones[segment.name]), keys(local.zones[segment.name]), [profile.zone])[0]
        )) ? "CIDR_BLOCK" : "SERVICE_CIDR_BLOCK"
        stateless   = profile.stateless
        min_port    = profile.min
        max_port    = profile.max
      }if profile.protocol == 6}
    }}
    security_groups = {for firewall in local.firewalls : firewall.name => { 
      display_name = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_${firewall.name}_filter"
    }}
    security_zones = local.zones
    subnets = {for subnet in local.subnets : subnet.name => {
      cidr_block    = local.subnet_cidr[segment.name][subnet.name]
      dns_label     = "${var.service.label}${index(local.vcn_list, segment.name) + 1}${substr(subnet.name, 0, 3)}"
      display_name  = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}"
      route_table   = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}_table"
      security_list = "${var.service.name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}_filter"
      stage         = subnet.stage
      prohibit_internet_ingress = contains(flatten(distinct(local.port_filter[subnet.firewall].ingress[*].zone)), "anywhere") ? false : true
      topology      = subnet.topology
    } if contains(var.service.topologies, subnet.topology)}
  }if segment.stage <= var.service.stage}
}