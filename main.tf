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
  topologies = flatten(compact([var.cloud == true ? "cloud" : "", var.host == true ? "host" : "", var.nodes == true ? "nodes" : "", var.container == true ? "container" : ""]))
  domains    = jsondecode(file("${path.module}/default/resident/domains.json"))
  segments   = jsondecode(file("${path.module}/default/network/segments.json"))
}

module "configuration" {
  source         = "./default/"
  providers = {oci = oci.service}
  tenancy = {
    tenancy_id     = var.tenancy_ocid
    compartment_id = var.compartment_ocid
    home           = var.region
    user_id        = var.current_user_ocid
  }
  resident = {
    topologies = local.topologies
    domains    = local.domains
    segments   = local.segments
  }
  service = {
    adb          = "${var.adb_type}_${var.adb_size}"
    class        = var.class
    region       = var.location
    organization = var.organization
    osn          = var.osn
    owner        = var.owner
    repository   = var.repository
    stage        = var.stage
    solution     = var.solution
    tenancy      = var.tenancy_ocid
    wallet       = var.wallet_type
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
  tenancy    = module.configuration.tenancy
  resident   = module.configuration.resident
  input = {
    # Reference to the deployment root. The service is setup in an encapsulating child compartment 
    parent_id     = var.tenancy_ocid
    # Enable compartment delete on destroy. If true, compartment will be deleted when `terraform destroy` is executed; If false, compartment will not be deleted on `terraform destroy` execution
    enable_delete = var.stage != "PROD" ? true : false
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
  tenancy    = module.configuration.tenancy
  resident   = module.configuration.resident
  encryption = module.configuration.encryption[each.key]
  input = {
    create = var.create_wallet
    type   = var.wallet_type == "Software" ? "DEFAULT" : "VIRTUAL_PRIVATE"
  }
  assets = {
    resident = module.resident
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
  depends_on = [module.configuration, module.resident]
  providers = {oci = oci.service}
  for_each  = {for segment in local.segments : segment.name => segment}
  tenancy   = module.configuration.tenancy
  resident  = module.configuration.resident
  network   = module.configuration.network[each.key]
  input = {
    internet = var.internet == "PUBLIC" ? "ENABLE" : "DISABLE"
    nat      = var.nat == true ? "ENABLE" : "DISABLE"
    ipv6     = var.ipv6
    osn      = var.osn
  }
  assets = {
    resident = module.resident
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
  tenancy    = module.configuration.tenancy
  resident   = module.configuration.resident
  database   = module.configuration.databases.autonomous
  input = {
    create   = var.create_adb
  }
  assets = {
    resident   = module.resident
    encryption = module.encryption["default"]
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
  input     = {
    network = module.network["core"]
    name    = "operator"
    shape   = "small"
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
