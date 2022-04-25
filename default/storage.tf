// Copyright (c) 2020 Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

output "storage" {
  value = {
    buckets = merge(
      {for bucket in local.buckets: format("%s_%s_%02d", var.service.name, "share", index(local.buckets, bucket) + 1) => {
        access_type  = lookup({"PRIVATE"="NoPublicAccess", "PUBLIC"="ObjectRead", "DOWNLOAD"="ObjectReadWithoutList"}, bucket.exposure, "NoPublicAccess")
        secret       = bucket.encryption
        metadata     = bucket.description
        name         = format("%s_%s_%s", var.service.name, bucket.name, "share")
        object_events_enabled = bucket.monitoring
        stage        = bucket.stage
        storage_tier = bucket.tiering
      }},
      {for bucket in local.buckets: format("%s_%s_%02d", var.service.name, "archive", index(local.buckets, bucket) + 1)  => {
        access_type  = lookup({"PRIVATE"="NoPublicAccess", "PUBLIC"="ObjectRead", "DOWNLOAD"="ObjectReadWithoutList"}, bucket.exposure, "NoPublicAccess")
        secret       = bucket.encryption
        metadata     = bucket.description
        name         = format("%s_%s_%s", var.service.name, bucket.name, "archive")
        object_events_enabled = false
        stage        = bucket.stage
        storage_tier = bucket.tiering
      }if bucket.tiering == "ENABLE"},
      {for backup in local.backups: format("%s_%s_%02d", var.service.name, "backup", index(local.backups, backup) + 1)  => {
        access_type  = "PRIVATE"
        secret       = backup.encryption
        metadata     = backup.description
        name         = format("%s_%s_%s", var.service.name, backup.name, "backup")
        object_events_enabled = false
        stage        = backup.stage
        storage_tier = "DISABLE"
      }}
    )
  }
}