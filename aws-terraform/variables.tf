# =============================================================================
# ANB Rising Stars - Terraform Variables
# Equivalent to CloudFormation Parameters in 00-master-stack.yaml
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------
variable "environment_name" {
  description = "Environment name prefix for all resources"
  type        = string
  default     = "anb-production"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.environment_name))
    error_message = "Environment name must contain only alphanumeric characters and hyphens."
  }
}

variable "key_pair_name" {
  description = "EC2 Key Pair for SSH access (must exist in your account)"
  type        = string
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------
variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = contains(["db.t3.micro", "db.t3.small", "db.t4g.micro", "db.t4g.small"], var.db_instance_class)
    error_message = "DB instance class must be one of: db.t3.micro, db.t3.small, db.t4g.micro, db.t4g.small."
  }
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "proyecto_1"
}

variable "db_username" {
  description = "Database admin username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database admin password (min 8 characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters."
  }
}

variable "allocated_storage" {
  description = "Database storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 100
    error_message = "Allocated storage must be between 20 and 100 GB."
  }
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (0 for AWS Academy)"
  type        = number
  default     = 0
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Application Configuration
# -----------------------------------------------------------------------------
variable "jwt_secret" {
  description = "JWT secret for authentication (min 32 characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "JWT secret must be at least 32 characters."
  }
}

variable "deployment_package_s3_key" {
  description = "S3 key path for deployment package"
  type        = string
  default     = "deployments/latest/app.tar.gz"
}

# -----------------------------------------------------------------------------
# API Auto Scaling Configuration
# -----------------------------------------------------------------------------
variable "api_instance_type" {
  description = "EC2 instance type for API servers"
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small", "t2.medium"], var.api_instance_type)
    error_message = "API instance type must be one of: t3.micro, t3.small, t3.medium, t2.micro, t2.small, t2.medium."
  }
}

variable "api_min_size" {
  description = "Minimum instances in API Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.api_min_size >= 1
    error_message = "API minimum size must be at least 1."
  }
}

variable "api_max_size" {
  description = "Maximum instances in API Auto Scaling Group"
  type        = number
  default     = 3

  validation {
    condition     = var.api_max_size >= 1 && var.api_max_size <= 10
    error_message = "API maximum size must be between 1 and 10."
  }
}

variable "api_desired_capacity" {
  description = "Desired instances in API Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.api_desired_capacity >= 1
    error_message = "API desired capacity must be at least 1."
  }
}

variable "cpu_target_value" {
  description = "Target CPU utilization for API auto scaling (%)"
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_target_value >= 40 && var.cpu_target_value <= 90
    error_message = "CPU target value must be between 40 and 90."
  }
}

# -----------------------------------------------------------------------------
# Worker Auto Scaling Configuration
# -----------------------------------------------------------------------------
variable "worker_instance_type" {
  description = "EC2 instance type for Worker servers"
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small", "t2.medium"], var.worker_instance_type)
    error_message = "Worker instance type must be one of: t3.micro, t3.small, t3.medium, t2.micro, t2.small, t2.medium."
  }
}

variable "worker_min_size" {
  description = "Minimum worker instances in Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.worker_min_size >= 0 && var.worker_min_size <= 3
    error_message = "Worker minimum size must be between 0 and 3."
  }
}

variable "worker_max_size" {
  description = "Maximum worker instances in Auto Scaling Group"
  type        = number
  default     = 3

  validation {
    condition     = var.worker_max_size >= 1 && var.worker_max_size <= 10
    error_message = "Worker maximum size must be between 1 and 10."
  }
}

variable "worker_desired_capacity" {
  description = "Desired worker instances in Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.worker_desired_capacity >= 0
    error_message = "Worker desired capacity must be at least 0."
  }
}

variable "worker_concurrency" {
  description = "Concurrent video tasks per worker"
  type        = number
  default     = 4

  validation {
    condition     = var.worker_concurrency >= 1 && var.worker_concurrency <= 12
    error_message = "Worker concurrency must be between 1 and 12."
  }
}

variable "target_queue_depth" {
  description = "Target queue depth per worker for auto scaling"
  type        = number
  default     = 10

  validation {
    condition     = var.target_queue_depth >= 1 && var.target_queue_depth <= 100
    error_message = "Target queue depth must be between 1 and 100."
  }
}

# -----------------------------------------------------------------------------
# SQS Queue Configuration
# -----------------------------------------------------------------------------
variable "message_retention_period" {
  description = "SQS message retention period in seconds (4 days default)"
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_period >= 60 && var.message_retention_period <= 1209600
    error_message = "Message retention period must be between 60 and 1209600 seconds."
  }
}

variable "visibility_timeout" {
  description = "SQS visibility timeout in seconds (15 min default)"
  type        = number
  default     = 900

  validation {
    condition     = var.visibility_timeout >= 0 && var.visibility_timeout <= 43200
    error_message = "Visibility timeout must be between 0 and 43200 seconds."
  }
}

variable "max_receive_count" {
  description = "Max receive count before sending to DLQ"
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "Max receive count must be between 1 and 1000."
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR for Public Subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR for Public Subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR for Private Subnet 1 (for RDS)"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR for Private Subnet 2 (for RDS)"
  type        = string
  default     = "10.0.12.0/24"
}

# -----------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------
variable "video_storage_bucket_name" {
  description = "S3 bucket name for video storage (leave empty for auto-generated)"
  type        = string
  default     = ""
}

variable "create_s3_bucket" {
  description = "Whether to create the S3 bucket (false if bucket already exists)"
  type        = bool
  default     = false
}
