# =============================================================================
# ANB Rising Stars - RDS Module
# Equivalent to 04-rds-database.yaml
# =============================================================================

# -----------------------------------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.environment_name}-db-subnet-group"
  description = "Subnet group for RDS PostgreSQL"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name        = "${var.environment_name}-db-subnet-group"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# DB Parameter Group
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name        = "${var.environment_name}-db-params"
  family      = "postgres15"
  description = "PostgreSQL 15 parameter group for ANB"

  parameter {
    name         = "max_connections"
    value        = "100"
    apply_method = "pending-reboot"  # Static parameter requires reboot to apply
  }

  tags = {
    Name        = "${var.environment_name}-db-params"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# RDS Instance - Simplified configuration for AWS Academy
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.environment_name}-postgres"

  # Engine configuration
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = var.db_instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = "gp2"
  storage_encrypted    = false  # AWS Academy limitation

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false
  multi_az               = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup and maintenance - Simplified for AWS Academy
  backup_retention_period   = 0  # AWS Academy limitation
  auto_minor_version_upgrade = false
  deletion_protection       = false
  skip_final_snapshot       = true

  tags = {
    Name        = "${var.environment_name}-postgres"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

# High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment_name}-rds-high-cpu"
  alarm_description   = "Alert when RDS CPU exceeds 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = {
    Name        = "${var.environment_name}-rds-high-cpu"
    Environment = var.environment_name
  }
}

# Low Storage Alarm
resource "aws_cloudwatch_metric_alarm" "low_storage" {
  alarm_name          = "${var.environment_name}-rds-low-storage"
  alarm_description   = "Alert when RDS free storage falls below 2GB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000  # 2GB in bytes
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = {
    Name        = "${var.environment_name}-rds-low-storage"
    Environment = var.environment_name
  }
}

# High Connections Alarm
resource "aws_cloudwatch_metric_alarm" "high_connections" {
  alarm_name          = "${var.environment_name}-rds-high-connections"
  alarm_description   = "Alert when database connections exceed 80"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = {
    Name        = "${var.environment_name}-rds-high-connections"
    Environment = var.environment_name
  }
}
