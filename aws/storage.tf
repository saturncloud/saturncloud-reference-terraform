# The Saturn bucket itself is created by ./bucket, before this stack, because
# it also holds this stack's Terraform state (as in saturn-aws).

resource "aws_s3_bucket_lifecycle_configuration" "saturn_bucket" {
  count  = var.object_storage_enabled ? 1 : 0
  bucket = local.saturn_bucket_name

  rule {
    id = "saturnfs-expire-incomplete-uploads"
    filter {
      prefix = "saturnfs/"
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = var.object_storage_upload_expiration_days
    }
    status = "Enabled"
  }
}

# Shared folders (network filesystem), off by default as in saturn-aws.
resource "aws_security_group" "saturn_nfs_efs" {
  count       = var.network_filesystem_enabled ? 1 : 0
  name        = "saturn-nfs-efs"
  description = "EFS filesystem for NFS feature"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "EFS port"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_efs_file_system" "saturn_nfs_efs" {
  count            = var.network_filesystem_enabled ? 1 : 0
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
}

resource "aws_efs_backup_policy" "saturn_nfs_efs" {
  count          = var.network_filesystem_enabled ? 1 : 0
  file_system_id = aws_efs_file_system.saturn_nfs_efs[0].id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "saturn_nfs_efs" {
  count           = var.network_filesystem_enabled ? 1 : 0
  file_system_id  = aws_efs_file_system.saturn_nfs_efs[0].id
  subnet_id       = aws_subnet.private[0].id
  security_groups = [aws_security_group.saturn_nfs_efs[0].id]
}
