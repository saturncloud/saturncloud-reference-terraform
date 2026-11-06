resource "aws_security_group" "saturn_nfs_efs" {
  count = var.manage_efs ? 1 : 0
  name        = "saturn-nfs-efs"
  description = "EFS filesystem for NFS feature"
  vpc_id      = var.vpc_id

  ingress {
    description = "EFS port"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(
    var.tags,
    {
      app = "Saturn"
    },
  )
}

resource "aws_efs_file_system" "saturn_nfs_efs" {
  count = var.manage_efs ? 1 : 0
  encrypted = true
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(
    var.tags,
    {
      app = "Saturn"
    },
  )
}

resource "aws_efs_backup_policy" "saturn_nfs_efs_bk_policy" {
  count = var.manage_efs ? 1 : 0
  file_system_id = join("", aws_efs_file_system.saturn_nfs_efs[*].id)

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "saturn_nfs_efs_mt" {
  file_system_id = join("", aws_efs_file_system.saturn_nfs_efs[*].id)
  for_each = toset(var.manage_efs ? var.worker_subnet_ids : [])
  subnet_id = each.value
  security_groups = [join("", aws_security_group.saturn_nfs_efs[*].id)]
}
