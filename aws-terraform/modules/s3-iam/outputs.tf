# =============================================================================
# ANB Rising Stars - S3/IAM Module Outputs
# =============================================================================

locals {
  # If bucket was created, use its name; otherwise use the computed name
  output_bucket_name = var.create_bucket ? aws_s3_bucket.video_storage[0].id : (var.s3_bucket_name != "" ? var.s3_bucket_name : "anb-videos-${var.aws_account_id}-${var.aws_region}")
  output_bucket_arn  = var.create_bucket ? aws_s3_bucket.video_storage[0].arn : "arn:aws:s3:::${local.output_bucket_name}"
}

output "bucket_name" {
  description = "S3 bucket name for video storage"
  value       = local.output_bucket_name
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = local.output_bucket_arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = var.create_bucket ? aws_s3_bucket.video_storage[0].bucket_domain_name : "${local.output_bucket_name}.s3.amazonaws.com"
}

output "instance_profile_name" {
  description = "Instance profile name for EC2 (AWS Academy LabInstanceProfile)"
  value       = "LabInstanceProfile"
}

output "api_log_group_name" {
  description = "CloudWatch Log Group for API"
  value       = aws_cloudwatch_log_group.api.name
}

output "worker_log_group_name" {
  description = "CloudWatch Log Group for Workers"
  value       = aws_cloudwatch_log_group.worker.name
}
