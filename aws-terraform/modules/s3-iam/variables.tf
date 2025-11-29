# =============================================================================
# ANB Rising Stars - S3/IAM Module Variables
# =============================================================================

variable "environment_name" {
  description = "Environment name prefix"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for video storage (leave empty for auto-generated)"
  type        = string
  default     = ""
}

variable "create_bucket" {
  description = "Whether to create the S3 bucket"
  type        = bool
  default     = false
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}
