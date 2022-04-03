// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "resident" {
    value = {
        owner        = var.service.owner
        repository   = var.service.repository
        name         = local.service_name
        label        = local.service_label
        stage        = local.lifecycle[var.service.stage]
        region       = {
            key  = local.region_key
            name = local.region_name
        }
        compartments = {for domain in var.resident.domains : "${local.service_name}_${domain.name}_compartment" => domain.stage}
        groups       = {for operator in flatten(var.resident.domains[*].operators) : operator => "${local.service_name}_${operator}"}
        policies     = {for operator in local.operators : operator.name => {
            name        = "${local.service_name}_${operator.name}"
            compartment = local.group_map[operator.name]
            rules       = operator.rules
        }if contains(keys(local.group_map), operator.name) }
        notifications = {for channel in local.channels : "${local.service_name}_${channel.name}" => {
            topic     = "${local.service_name}_${channel.name}"
            protocol  = channel.type
            endpoint  = channel.address
        } if contains(distinct(flatten("${var.resident.domains[*].channels}")), channel.name)}
        tag_namespaces = {for namespace in local.controls : "${local.service_name}_${namespace.name}" => namespace.stage}
        tags = {for tag in local.tags : tag.name => {
            name          = tag.name
            namespace     = local.tag_map[tag.name]
            stage         = local.tag_namespaces["${local.tag_map[tag.name]}"]
            values        = tag.values
            default       = length(flatten([tag.values])) > 1 ? element(tag.values,0) : tostring(tag.values)
            cost_tracking = tag.cost_tracking
        }}
    }
}