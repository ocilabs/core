// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

// --- provider settings --- //
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}
// --- provider settings  --- //

// --- tenancy configuration --- //
provider "oci" {
  alias  = "service"
  region = var.location
}

variable "tenancy_ocid" {}
variable "region" {}
variable "compartment_ocid" {}
variable "current_user_ocid" {}

locals {
  topologies = flatten(compact([
    var.management == true ? "management" : "", 
    var.host == true ? "host" : "", 
    var.nodes == true ? "nodes" : "", 
    var.container == true ? "container" : ""
  ]))
  domains    = jsondecode(file("${path.module}/default/resident/domains.json"))
  segments   = jsondecode(file("${path.module}/default/network/segments.json"))
  wallets    = jsondecode(file("${path.module}/default/encryption/wallets.json"))
}

module "configuration" {
  source         = "./default/"
  providers = {oci = oci.service}
  account = {
    tenancy_id     = var.tenancy_ocid
    compartment_id = var.compartment_ocid
    home           = var.region
    user_id        = var.current_user_ocid
  }
  settings = {
    topologies = local.topologies
    domains    = local.domains
    segments   = local.segments
  }
  options = {
    adb          = "${var.adb_type}_${var.adb_size}"
    budget       = var.budget
    class        = var.class
    encrypt      = var.create_wallet
    name         = var.name
    region       = var.location
    organization = var.organization
    osn          = var.osn
    owner        = var.owner
    repository   = var.repository
    stage        = var.stage
    tenancy      = var.tenancy_ocid
    wallet       = var.wallet
  }
}
// --- tenancy configuration  --- //

// --- operation controls --- //
provider "oci" {
  alias  = "home"
  region = module.configuration.tenancy.region.key
}
module "resident" {
  source = "github.com/ocilabs/resident"
  depends_on = [module.configuration]
  providers  = {oci = oci.home}
  options = {
    # Enable compartment delete on destroy. If true, compartment will be deleted when `terraform destroy` is executed; If false, compartment will not be deleted on `terraform destroy` execution
    enable_delete = var.stage != "PRODUCTION" ? true : false
    # Reference to the deployment root. The service is setup in an encapsulating child compartment 
    parent_id     = var.tenancy_ocid
    user_id       = var.current_user_ocid
  }
  configuration = {
    tenancy  = module.configuration.tenancy
    resident = module.configuration.resident
  }
}
output "resident" {
  value = {for resource, parameter in module.resident : resource => parameter}
}
// --- operation controls --- //

// --- wallet configuration --- //
module "encryption" {
  source     = "github.com/ocilabs/encryption"
  depends_on = [module.configuration, module.resident]
  providers  = {oci = oci.service}
  for_each   = {for wallet in local.wallets : wallet.name => wallet}
  options = {
    create = var.create_wallet
    type   = var.wallet == "SOFTWARE" ? "DEFAULT" : "VIRTUAL_PRIVATE"
  }
  configuration = {
    tenancy    = module.configuration.tenancy
    resident   = module.configuration.resident
    encryption = module.configuration.encryption[each.key]
  }
  assets = {
    resident   = module.resident
  }
}
output "encryption" {
  value = {for resource, parameter in module.encryption : resource => parameter}
  sensitive = true
}
// --- wallet configuration --- //

// --- network configuration --- //
module "network" {
  source = "github.com/ocilabs/network"
  depends_on = [module.configuration, module.encryption, module.resident]
  providers = {oci = oci.service}
  for_each  = {for segment in local.segments : segment.name => segment}
  options = {
    internet = var.internet == "PUBLIC" ? "ENABLE" : "DISABLE"
    nat      = var.nat == true ? "ENABLE" : "DISABLE"
    ipv6     = var.ipv6
    osn      = var.osn
  }
  configuration = {
    tenancy = module.configuration.tenancy
    resident = module.configuration.resident
    network = module.configuration.network[each.key]
  }
  assets = {
    encryption = module.encryption["main"]
    resident   = module.resident
  }
}
output "network" {
  value = {for resource, parameter in module.network : resource => parameter}
}
// --- network configuration --- //

// --- database creation --- //
module "database" {
  source     = "github.com/ocilabs/database"
  depends_on = [module.configuration, module.resident, module.network, module.encryption]
  providers  = {oci = oci.service}
  options = {
    class    = var.class
    create   = var.create_adb
    password = var.create_wallet == false ? "RANDOM" : "VAULT"
  }
  configuration = {
    tenancy  = module.configuration.tenancy
    resident = module.configuration.resident
    database = module.configuration.database
  }
  assets = {
    encryption = module.encryption["main"]
    network    = module.network["core"]
    resident   = module.resident
  }
}
output "database" {
  value = {for resource, parameter in module.database : resource => parameter}
  sensitive = true
}
// --- database creation --- //


/*/ --- host configuration --- //
module "host" {
  source     = "./assets/host/"
  depends_on = [
    module.configuration, 
    module.resident, 
    module.network
  ]
  providers  = { oci = oci.home }
  tenancy   = module.configuration.tenancy
  service   = module.configuration.service
  resident  = module.configuration.resident
  config     = {
    network = module.network["core"]
    name    = "operator"
    shape   = "SMALL"
    image   = "linux"
    disk    = "san"
    nic     = "private"
  }
  ssh = {
    # Determine whether a ssh session via bastion service will be started
    enable          = false
    type            = "MANAGED_SSH" # Alternatively "PORT_FORWARDING"
    ttl_in_seconds  = 1800
    target_port     = 22
  }
}
output "host" {
  value = {
    for resource, parameter in module.host : resource => parameter
  }
}
// --- host configuration --- /*/
