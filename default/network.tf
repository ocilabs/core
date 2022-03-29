// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "network" { 
  value = {for segment in var.resolve.segments : segment.name => {
    name         = segment.name
    region       = var.input.region
    display_name = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}"
    dns_label    = "${local.service_label}${index(local.vcn_list, segment.name) + 1}"
    compartment  = contains(flatten(var.resolve.domains[*].name), "network") ? "${local.service_name}_network_compartment" : local.service_name
    stage        = segment.stage
    cidr         = segment.cidr
    gateways = {
      drg = {
        name     = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_drg"
        create   = anytrue([contains(local.routers[*].name, segment.name), contains(local.routers[*].name, "default")])
        type     = "VCN"
        cpe      = try(local.router_map[segment.name].cpe, local.router_map["default"].cpe)
        anywhere = try(local.router_map[segment.name].anywhere, local.router_map["default"].anywhere)
      }
        internet = {
        name   = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_internet"
      }
        nat = {
        name          = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_nat"
      }
        osn = {
        name     = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_osn"
        services = var.input.osn == "ALL" ? "all" : "storage"
        all      = local.osn_cidrs.all
        storage  = local.osn_cidrs.storage
      }
    }
    route_tables = {for table in flatten(distinct(flatten(local.firewalls[*].outgoing))) : "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${table}_table" => {
      display_name = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${table}_table",
      route_rules  = flatten([for rule in keys(local.route_rules): [for destination in local.route_rules[rule] : {
        description      = "Routes ${local.destination_map[destination].name} traffic via the ${local.destination_map[destination].gateway} gateway."
        destination    = matchkeys(values(local.zones[segment.name]), keys(local.zones[segment.name]), [rule])[0]
        destination_type = local.destination_map[destination].gateway == "osn" ? "SERVICE_CIDR_BLOCK" : "CIDR_BLOCK"
        network_entity = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${local.destination_map[destination].gateway}"
        zestination    = destination
      }if local.destination_map[destination].name == table]])
    }}
    security_lists = {for subnet in local.subnets : subnet.name => { 
      display_name = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}_filter"
      ingress      = {for profile in local.port_filter[subnet.firewall].ingress: "${profile.firewall}_${profile.zone}_${profile.port}_${profile.transport}" => {
        protocol    = profile.protocol
        description = "Allow incoming ${profile.port} traffic from ${profile.zone} via the ${profile.firewall} port filter"
        source      = matchkeys(values(local.zones[segment.name]), keys(local.zones[segment.name]), [profile.zone])[0]
        stateless   = profile.stateless
        min_port    = profile.min
        max_port    = profile.max
      }}
    }}
    security_groups = {for firewall in local.firewalls : firewall.name => { 
      display_name = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${firewall.name}_filter"
    }}
    security_zones = local.zones
    subnets = {for subnet in local.subnets : subnet.name => {
      topology      = subnet.topology
      display_name  = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}"
      cidr_block    = local.subnet_cidr[segment.name][subnet.name]
      dns_label     = "${local.service_label}${index(local.vcn_list, segment.name) + 1}${substr(subnet.name, 0, 3)}"
      route_table   = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${subnet.firewall}_table"
      security_list = "${local.service_name}_${index(local.vcn_list, segment.name) + 1}_${subnet.name}_filter"
    } if contains(var.resolve.topologies, subnet.topology)}
  }if segment.stage <= local.lifecycle[var.input.stage]}
}