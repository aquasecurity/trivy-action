# test data for trivy config with terraform variables

variable "bucket_versioning_enabled" {
  type    = string
  default = "Disabled"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "trivy-action-bucket"
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = var.bucket_versioning_enabled
  }
}