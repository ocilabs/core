// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Tenancy Classification
variable "class" {
  type        = string
  description = "The tenancy classification sets boundaries for resource deployments"
  default     = "PAYG"
}
# Resident Configuration
/*
variable "parent" {
  type        = string
  description = "The Oracle Cloud Identifier (OCID) for a parent compartment, an encapsulating child compartment will be created to define the service resident. Usually this is the root compartment, hence the tenancy OCID."
}
*/

variable "organization" { 
  type        = string
  description = "The organization represents an unique identifier for a service owner and triggers the definition of groups on root compartment level"
  default     =  "Organization"
}

variable "solution" { 
  type        = string
  description = "The solution represents an unique identifier for a service defined on root compartment level"
}

variable "repository" {
  type        = string
  description = "The service configuration is stored using infrastructure code in a repository"
}

variable "owner" {
  type        = string
  description = "The service owner is identified by his or her eMail address"
  default     = "RobotNotExist@oracle.com"
}

variable "stage"           { 
  type        = string
  description = "The stage variable triggers lifecycle related resources to be provisioned"
  default     = "DEV"
}

variable "region" {
  type        = string
  description = "The region defines the target region for service deployments"
}

variable "cloud" {
  type        = bool
  description = "Provisioning a network topology allows to access Oracle's public cloud services via a private transfer domain."
  default     = true
}

# Service Topologies
variable "host" {
  type        = bool
  description = "Provisioning a host topology prepares a service resident to deploy a traditional enterprise application with presentation, application and database tier."
}

variable "nodes" {
  type        = bool
  description = "Provisioning a nodes topology prepares a service resident to deploy automatically scaling services separated front- and backend tier for services like like big data or mobile backend."
}

variable "container" {
  type        = bool
  description = "Provisioning a container topology prepares a service resident to deploy cloud native services on Oracle's Kubernetes Engine (OKE)."
}

# Network Settings
variable "internet" {
  type        = string
  description = "Allows or disallows to provision resources with public IP addresses."
  default     = "PUBLIC"
}

variable "nat" {
  type        = bool
  description = "Enables or disables routes through a NAT Gateway."
  default     = true
}

variable "ipv6" {
  type        = bool
  description = "Triggers the release of IPv6 addresses inside the VCN."
  default     = false
}

variable "osn" {
  type        = string
  description = "Configures the scope for the service gateway"
  default     = "ALL_SERVICES"
}

// Enable Encryption
variable "create_wallet" {
  type        = bool
  description = "Define whether wallets is created or not"
  default     = false
}
variable "wallet_type" {
  type        = string
  description = "Define the storage entity, either Software or HSM"
  default     = "Software"
}

// Database Selection
variable "create_adb" {
  type        = bool
  description = "Define whether a database is created or not"
}
variable "adb_type" {
  type        = string
  description = "Configures the autonomous database type"
  default     = "TRANSACTION_PROCESSING"
}