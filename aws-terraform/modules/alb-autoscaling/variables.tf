# =============================================================================
# ANB Rising Stars - ALB/ASG Module Variables
# =============================================================================

variable "environment_name" {
  description = "Environment name prefix"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 Key Pair for SSH access"
  type        = string
}

variable "api_instance_type" {
  description = "EC2 instance type for API servers"
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "cpu_target_value" {
  description = "Target CPU utilization for scaling"
  type        = number
  default     = 70
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Database endpoint address"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "proyecto_1"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for video storage"
  type        = string
}

variable "deployment_package_s3_key" {
  description = "S3 key for deployment package"
  type        = string
  default     = "deployments/latest/app.tar.gz"
}

variable "sqs_queue_url" {
  description = "SQS Queue URL for video processing"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "instance_security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}
