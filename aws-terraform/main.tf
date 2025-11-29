# =============================================================================
# ANB Rising Stars - Terraform Infrastructure
# Main orchestration file - equivalent to 00-master-stack.yaml
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment_name
      Project     = "ANB-Rising-Stars"
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# Module 1: VPC and Networking
# =============================================================================
module "vpc" {
  source = "./modules/vpc"

  environment_name    = var.environment_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)
}

# =============================================================================
# Security Group for EC2 Instances (API and Workers)
# =============================================================================
resource "aws_security_group" "ec2" {
  name        = "${var.environment_name}-ec2-sg"
  description = "Security group for EC2 instances (API and Workers)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere (for ALB and direct access)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API port for ALB health checks"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-ec2-sg"
  }
}

# =============================================================================
# Module 2: S3 and IAM
# =============================================================================
module "s3_iam" {
  source = "./modules/s3-iam"

  environment_name         = var.environment_name
  s3_bucket_name           = var.video_storage_bucket_name
  create_bucket            = var.create_s3_bucket
  aws_account_id           = data.aws_caller_identity.current.account_id
  aws_region               = var.aws_region
}

# =============================================================================
# Module 3: SQS Queue for Video Processing
# =============================================================================
module "sqs" {
  source = "./modules/sqs"

  environment_name         = var.environment_name
  message_retention_period = var.message_retention_period
  visibility_timeout       = var.visibility_timeout
  max_receive_count        = var.max_receive_count
}

# =============================================================================
# Module 4: RDS Database
# =============================================================================
module "rds" {
  source = "./modules/rds"

  environment_name        = var.environment_name
  db_instance_class       = var.db_instance_class
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  allocated_storage       = var.allocated_storage
  backup_retention_period = var.backup_retention_period
  multi_az                = var.multi_az

  private_subnet_ids      = module.vpc.private_subnet_ids
  rds_security_group_id   = module.vpc.rds_security_group_id

  depends_on = [module.vpc]
}

# =============================================================================
# Module 5: ALB and API Auto Scaling Group
# =============================================================================
module "alb_autoscaling" {
  source = "./modules/alb-autoscaling"

  environment_name        = var.environment_name
  key_pair_name           = var.key_pair_name
  api_instance_type       = var.api_instance_type
  min_size                = var.api_min_size
  max_size                = var.api_max_size
  desired_capacity        = var.api_desired_capacity
  cpu_target_value        = var.cpu_target_value
  jwt_secret              = var.jwt_secret
  db_password             = var.db_password
  db_host                 = module.rds.db_endpoint
  db_name                 = var.db_name
  db_username             = var.db_username
  s3_bucket_name          = module.s3_iam.bucket_name
  deployment_package_s3_key = var.deployment_package_s3_key
  sqs_queue_url           = module.sqs.queue_url

  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  alb_security_group_id   = module.vpc.alb_security_group_id
  instance_security_group_id = aws_security_group.ec2.id
  aws_region              = var.aws_region

  depends_on = [module.vpc, module.s3_iam, module.rds, module.sqs]
}

# =============================================================================
# Module 6: Worker Auto Scaling Group
# =============================================================================
module "workers" {
  source = "./modules/workers"

  environment_name        = var.environment_name
  key_pair_name           = var.key_pair_name
  worker_instance_type    = var.worker_instance_type
  min_size                = var.worker_min_size
  max_size                = var.worker_max_size
  desired_capacity        = var.worker_desired_capacity
  worker_concurrency      = var.worker_concurrency
  target_queue_depth      = var.target_queue_depth
  db_password             = var.db_password
  db_host                 = module.rds.db_endpoint
  db_name                 = var.db_name
  db_username             = var.db_username
  s3_bucket_name          = module.s3_iam.bucket_name
  deployment_package_s3_key = var.deployment_package_s3_key
  sqs_queue_url           = module.sqs.queue_url
  sqs_queue_name          = module.sqs.queue_name

  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  instance_security_group_id = aws_security_group.ec2.id
  aws_region              = var.aws_region

  depends_on = [module.vpc, module.s3_iam, module.rds, module.sqs, module.alb_autoscaling]
}
