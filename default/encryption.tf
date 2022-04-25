// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "encryption" {
  value = {for wallet in local.wallets : wallet.name => {
    compartment = contains(flatten(local.domains[*].name), "operation") ? "${var.service.name}_operation_compartment" : var.service.name
    stage     = wallet.stage
    vault     = "${var.service.name}_${wallet.name}_vault"
    key       = {
      name      = "${var.service.name}_${wallet.name}_key"
      algorithm = wallet.algorithm
      length    = wallet.length
    }
    signatures = {for signature in local.signatures : signature.name => {
      message   = signature.message
      type      = signature.type
      algorithm = signature.algorithm
    }if contains(wallet.signatures, signature.name)}
    secrets = {for secret in local.secrets : secret.resource => {
      name   = "${var.service.name}_${secret.resource}_secret"
      phrase = secret.phrase
    }if var.service.encrypt == true}
    passwords = [
      for secret in local.secrets : "${var.service.name}_${secret.resource}_password"
      if var.service.encrypt == false
    ]
  }}
}