// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "resident" {
  value = {
    label  = var.service.label
    name   = var.service.name
    owner  = var.service.owner
    label  = var.service.label
    name   = var.service.name
    region = {
      key  = local.region_key
      name = local.region_name
    }
    repository   = var.service.repository
    service = {
      budgets = merge(
        zipmap(
          flatten([for period in local.periods: [for alert in local.alerts: "${var.service.name}_${lower(period.type)}" if alert.name == "compartment" && period.name == "default" && var.service.budget > 0]]),
          flatten([for period in local.periods: [for alert in local.alerts: {
            amount         = var.service.budget
            budget_processing_period_start_offset = period.offset
            display_name   = "${var.service.name}_${lower(period.type)}"
            reset_period   = period.type
            stage          = 0
            target_type    = "COMPARTMENT"
            threshold      = alert.threshold
            threshold_type = alert.measure
          } if alert.name == "compartment" && period.name == "default" && var.service.budget > 0]])
        ),
        zipmap(
          flatten([for domain in local.domains: [for period in local.periods: [for alert in local.alerts: "${domain.name}_${lower(period.type)}" if alert.name == "compartment" && period.name == "default" && domain.budget > 0]]]),
          flatten([for domain in local.domains: [for period in local.periods: [for alert in local.alerts: {
            amount = domain.budget
            budget_processing_period_start_offset = period.offset
            display_name   = "${domain.name}_${lower(period.type)}"
            reset_period   = period.type
            stage          = domain.stage
            target_type    = "COMPARTMENT"
            threshold      = alert.threshold
            threshold_type = alert.measure
          }if alert.name == "compartment" && period.name == "default" && domain.budget > 0]]])
        ),
        zipmap(
          flatten([for budget in local.budgets: [for period in local.periods: [for alert in local.alerts: "${budget.name}_${lower(period.type)}" if budget.alert == alert.name && budget.period == period.name]]]),
          flatten([for budget in local.budgets: [for period in local.periods: [for alert in local.alerts: {
            amount         = budget.amount
            budget_processing_period_start_offset = period.offset
            display_name   = "${budget.name}_${lower(period.type)}"
            reset_period   = period.type
            stage          = budget.stage
            target_type    = "TAG"
            threshold      = alert.threshold
            threshold_type = alert.measure
          }if budget.alert == alert.name && budget.period == period.name]]])
        )
      )
      compartments = {
        for domain in local.domains : "${var.service.name}_${domain.name}_compartment" => domain.stage
      }
      notifications = {for channel in local.channels : "${var.service.name}_${channel.name}" => {
        topic     = "${var.service.name}_${channel.name}"
        protocol  = channel.type
        endpoint  = channel.address
      } if contains(distinct(flatten("${local.domains[*].channels}")), channel.name)}
      policies     = {for operator in local.operators : operator.name => {
        name        = "${var.service.name}_${operator.name}"
        compartment = local.group_map[operator.name]
        rules       = operator.rules
      }if contains(keys(local.group_map), operator.name) }
      tags = merge(
        {for tag in local.controls : tag.name => {
          cost_tracking = false
          default       = tag.values[0]
          name          = tag.name
          namespace     = "${var.service.name}_${tag.monitor}"
          stage         = tag.stage
          values        = tag.values
        }},
        {for tag in distinct(local.budgets.*.monitor): tag => {
          cost_tracking = true
          default       = {for budget in local.budgets : budget.monitor => budget.name...}[tag].0
          name          = tag
          namespace     = "${var.service.name}_budget"
          stage         = min({for budget in local.budgets : budget.monitor => budget.stage...}[tag]...)
          values        = {for budget in local.budgets : budget.monitor => budget.name...}[tag]
        }}
      )
    }
    stage        = var.service.stage
    tenancy = {
      groups       = {
        for operator in flatten(local.domains[*].operators) : operator => "${var.service.name}_${operator}"
      }
      tag_namespaces = merge(
        {for space in distinct(local.controls[*].monitor): "${var.service.name}_${space}" => min([for value in local.controls: value.stage if value.monitor == space]...)},
        {"${var.service.name}_budget" : min(local.budgets.*.stage...)}
      )
    }
  }
}