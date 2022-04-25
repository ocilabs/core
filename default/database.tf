// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "database" {
  value = flatten(distinct([for adb in local.adb_types: [for size in local.adb_sizes : {
    compartment  = contains(flatten(local.domains[*].name), "database") ? "${var.service.name}_database_compartment" : var.service.name
    cores        = size.cores
    display_name = "${var.service.name}_database"
    license      = adb.license
    name         = format(
      "%s%s", 
      lower(adb.type), 
      lower(size.name)
    )
    password     = var.service.encrypt? "${var.service.name}_${adb.password}_secret" : "${var.service.name}_${adb.password}_password"
    stage        = adb.stage
    storage      = size.storage
    type         = adb.type
    version      = adb.version
  }if lower(var.service.adb) == lower("${adb.name}_${upper(size.name)}")]]))
}