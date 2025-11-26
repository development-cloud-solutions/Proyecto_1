# =============================================================================
# ANB Rising Stars - S3 and IAM Module
# Equivalent to 02-s3-iam.yaml
# =============================================================================

locals {
  bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "anb-videos-${var.aws_account_id}-${var.aws_region}"
}

# -----------------------------------------------------------------------------
# S3 Bucket for Video Storage (conditional creation)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "video_storage" {
  count  = var.create_bucket ? 1 : 0
  bucket = local.bucket_name

  tags = {
    Name        = "${var.environment_name}-video-storage"
    Environment = var.environment_name
    Application = "ANB-Rising-Stars"
  }
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "video_storage" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.video_storage[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "video_storage" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.video_storage[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "video_storage" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.video_storage[0].id

  # Move processed videos to Glacier after 90 days
  rule {
    id     = "MoveProcessedVideosToGlacier"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  # Delete old uploads after 30 days
  rule {
    id     = "DeleteOldUploads"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      days = 30
    }
  }

  # Delete incomplete multipart uploads after 7 days
  rule {
    id     = "DeleteIncompleteMultipartUploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CORS configuration
resource "aws_s3_bucket_cors_configuration" "video_storage" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.video_storage[0].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag", "x-amz-request-id"]
    max_age_seconds = 3000
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "video_storage" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.video_storage[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy - Deny non-SSL requests
resource "aws_s3_bucket_policy" "video_storage" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.video_storage[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.video_storage[0].arn,
          "${aws_s3_bucket.video_storage[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/ec2/anb-api"
  retention_in_days = 7

  tags = {
    Name        = "${var.environment_name}-api-logs"
    Environment = var.environment_name
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/ec2/anb-worker"
  retention_in_days = 7

  tags = {
    Name        = "${var.environment_name}-worker-logs"
    Environment = var.environment_name
  }
}

resource "aws_cloudwatch_log_group" "user_data" {
  name              = "/aws/ec2/anb-user-data"
  retention_in_days = 3

  tags = {
    Name        = "${var.environment_name}-user-data-logs"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# NOTE: AWS Academy does not allow creating IAM roles
# Use the pre-existing LabInstanceProfile
# -----------------------------------------------------------------------------
