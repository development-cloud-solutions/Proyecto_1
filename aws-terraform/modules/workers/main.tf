# =============================================================================
# ANB Rising Stars - Workers Auto Scaling Module
# Equivalent to 06-workers-autoscaling.yaml
# =============================================================================

# Data source for latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------------------------------------------------------
# Launch Template for Worker Instances
# -----------------------------------------------------------------------------
resource "aws_launch_template" "worker" {
  name          = "${var.environment_name}-worker-launch-template"
  image_id      = data.aws_ssm_parameter.ami.value
  instance_type = var.worker_instance_type
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.instance_security_group_id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    aws_region              = var.aws_region
    s3_bucket_name          = var.s3_bucket_name
    deployment_package_s3_key = var.deployment_package_s3_key
    db_host                 = var.db_host
    db_name                 = var.db_name
    db_username             = var.db_username
    db_password             = var.db_password
    sqs_queue_url           = var.sqs_queue_url
    worker_concurrency      = var.worker_concurrency
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment_name}-worker-asg"
      Environment = var.environment_name
      Type        = "Worker"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment_name}-worker-volume"
      Environment = var.environment_name
    }
  }

  tags = {
    Name        = "${var.environment_name}-worker-launch-template"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Group for Workers
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "worker" {
  name                      = "${var.environment_name}-worker-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "EC2"
  health_check_grace_period = 600  # 10 minutes

  vpc_zone_identifier = var.public_subnet_ids

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment_name}-worker-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Type"
    value               = "Worker"
    propagate_at_launch = true
  }
}

# -----------------------------------------------------------------------------
# Scaling Policy based on SQS Queue Depth
# Scales when the number of messages exceeds TargetQueueDepth (default: 10)
# Example: If TargetQueueDepth=10 and there are 30 messages, scales to ~3 workers
# -----------------------------------------------------------------------------
resource "aws_autoscaling_policy" "worker" {
  name                      = "${var.environment_name}-worker-sqs-policy"
  autoscaling_group_name    = aws_autoscaling_group.worker.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 180

  target_tracking_configuration {
    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      metric_dimension {
        name  = "QueueName"
        value = var.sqs_queue_name
      }
    }
    target_value     = var.target_queue_depth
    disable_scale_in = false
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Workers
# -----------------------------------------------------------------------------

# High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "worker_high_cpu" {
  alarm_name          = "${var.environment_name}-worker-asg-high-cpu"
  alarm_description   = "Alert when Worker ASG average CPU exceeds 85%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker.name
  }

  tags = {
    Name        = "${var.environment_name}-worker-asg-high-cpu"
    Environment = var.environment_name
  }
}

# Low Capacity Alarm
resource "aws_cloudwatch_metric_alarm" "worker_low_capacity" {
  alarm_name          = "${var.environment_name}-worker-asg-low-capacity"
  alarm_description   = "Alert when no workers are running"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.worker.name
  }

  tags = {
    Name        = "${var.environment_name}-worker-asg-low-capacity"
    Environment = var.environment_name
  }
}
