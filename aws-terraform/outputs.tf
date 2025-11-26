# =============================================================================
# ANB Rising Stars - Terraform Outputs
# Equivalent to CloudFormation Outputs in 00-master-stack.yaml
# =============================================================================

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------
output "environment_name" {
  description = "Environment name"
  value       = var.environment_name
}

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# -----------------------------------------------------------------------------
# S3 Outputs
# -----------------------------------------------------------------------------
output "s3_bucket_name" {
  description = "S3 bucket for video storage"
  value       = module.s3_iam.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.s3_iam.bucket_arn
}

# -----------------------------------------------------------------------------
# Database Outputs
# -----------------------------------------------------------------------------
output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_endpoint
}

output "db_connection_string" {
  description = "Database connection string (without password)"
  value       = module.rds.db_connection_string
}

# -----------------------------------------------------------------------------
# Application Outputs
# -----------------------------------------------------------------------------
output "application_url" {
  description = "Application URL (Load Balancer)"
  value       = module.alb_autoscaling.load_balancer_url
}

output "load_balancer_dns" {
  description = "Load Balancer DNS name"
  value       = module.alb_autoscaling.load_balancer_dns
}

# -----------------------------------------------------------------------------
# Auto Scaling Outputs
# -----------------------------------------------------------------------------
output "api_autoscaling_group_name" {
  description = "API Auto Scaling Group name"
  value       = module.alb_autoscaling.autoscaling_group_name
}

# -----------------------------------------------------------------------------
# SQS Outputs
# -----------------------------------------------------------------------------
output "sqs_queue_url" {
  description = "SQS Queue URL for video processing"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "SQS Queue ARN"
  value       = module.sqs.queue_arn
}

output "sqs_queue_name" {
  description = "SQS Queue Name"
  value       = module.sqs.queue_name
}

output "sqs_dlq_url" {
  description = "SQS Dead Letter Queue URL"
  value       = module.sqs.dlq_url
}

# -----------------------------------------------------------------------------
# Worker Auto Scaling Outputs
# -----------------------------------------------------------------------------
output "worker_autoscaling_group_name" {
  description = "Worker Auto Scaling Group name"
  value       = module.workers.autoscaling_group_name
}

output "worker_launch_template_id" {
  description = "Worker Launch Template ID"
  value       = module.workers.launch_template_id
}

