resource "aws_s3_bucket_lifecycle_configuration" "saturn_bucket_lifecycle" {
  count = var.object_storage_enabled ? 1 : 0
  bucket = var.saturn_bucket_name

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
