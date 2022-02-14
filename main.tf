// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

// readme.md created with https://terraform-docs.io/: terraform-docs markdown --sort=false ./ > ./readme.md

// --- provider settings --- //
terraform {
  required_providers {
    oci = {
      source = "hashicorp/oci"
    }
  }
}
provider "oci" { 
  alias = "init"
}
provider "oci" {
  alias  = "home"
  region = module.configuration.tenancy.region.key
}
// --- provider settings  --- //

// --- tenancy configuration --- //
variable "tenancy_ocid" { }

module "configuration" {
  source         = "./default/"

  options = {
    domains      = var.domains
    segments     = var.segments
  }
  input = {
    tenancy      = var.tenancy_ocid
    class        = var.class
    owner        = var.owner
    organization = var.organization
    solution     = var.solution
    repository   = var.repository
    stage        = var.stage
    region       = var.region
    # to be deleted
    domains      = var.domains
    segments     = var.segments
  }
}
output "tenancy"   {
  value = module.configuration.tenancy
  description = "Retrieved configuration details for the tenancy"
}
// --- tenancy configuration  --- //

// --- operation controls --- //
module "resident" {
  source = "github.com/torstenboettjer/ocloud-assets-resident"
  depends_on = [
    module.configuration
  ]
  providers = {oci = oci.init}
  tenancy   = module.configuration.tenancy
  resident  = module.configuration.resident
  input = {
    # Reference to the deployment root. The service is setup in an encapsulating child compartment 
    parent_id     = var.tenancy_ocid
    # Enable compartment delete on destroy. If true, compartment will be deleted when `terraform destroy` is executed; If false, compartment will not be deleted on `terraform destroy` execution
    enable_delete = var.stage != "PROD" ? true : false
  }
  configuration = {
    tenancy   = module.configuration.tenancy
    resident  = module.configuration.resident
  }
}
output "resident" {
  value = {
    for resource, parameter in module.resident : resource => parameter
  }
}
// --- operation controls --- //

// --- network configuration --- //
module "network" {
  source = "github.com/torstenboettjer/ocloud-assets-network"
  depends_on = [ 
    module.configuration, 
    module.resident
  ]
  providers = { oci = oci.home }
  for_each  = {for segment in var.segments : segment.name => segment}
  tenancy   = module.configuration.tenancy
  resident  = module.configuration.resident
  network   = module.configuration.network[each.key]
  input = {
    resident = module.resident
  }
  configuration = {
    tenancy   = module.configuration.tenancy
    resident  = module.configuration.resident
    network   = module.configuration.network[each.key]
  }
  assets = {
    resident = module.resident
  }
}
output "network" {
  value = {
    for resource, parameter in module.network : resource => parameter
    }
}
// --- network configuration --- //


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