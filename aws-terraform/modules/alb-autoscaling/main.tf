# =============================================================================
# ANB Rising Stars - ALB and API Auto Scaling Module
# Equivalent to 05-alb-autoscaling.yaml
# =============================================================================

# Data source for latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.environment_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  ip_address_type    = "ipv4"

  tags = {
    Name        = "${var.environment_name}-alb"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# Target Group for API Instances
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "api" {
  name                 = "${var.environment_name}-api-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health"
    port                = "80"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200"
  }

  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = {
    Name        = "${var.environment_name}-api-tg"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# ALB Listener (HTTP)
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# -----------------------------------------------------------------------------
# Launch Template for API Instances
# -----------------------------------------------------------------------------
resource "aws_launch_template" "api" {
  name          = "${var.environment_name}-api-launch-template"
  image_id      = data.aws_ssm_parameter.ami.value
  instance_type = var.api_instance_type
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
    jwt_secret              = var.jwt_secret
    sqs_queue_url           = var.sqs_queue_url
    alb_dns_name            = aws_lb.main.dns_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment_name}-api-instance"
      Environment = var.environment_name
      Type        = "API"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment_name}-api-volume"
      Environment = var.environment_name
    }
  }

  tags = {
    Name        = "${var.environment_name}-api-launch-template"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Group
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "api" {
  name                      = "${var.environment_name}-api-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "ELB"
  health_check_grace_period = 600  # 10 minutes for download and build

  vpc_zone_identifier = var.public_subnet_ids
  target_group_arns   = [aws_lb_target_group.api.arn]

  launch_template {
    id      = aws_launch_template.api.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment_name}-api-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment_name
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]
}

# -----------------------------------------------------------------------------
# Auto Scaling Policy - Target Tracking (CPU)
# -----------------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.environment_name}-api-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.api.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

# High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment_name}-asg-high-cpu"
  alarm_description   = "Alert when ASG average CPU exceeds 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.api.name
  }

  tags = {
    Name        = "${var.environment_name}-asg-high-cpu"
    Environment = var.environment_name
  }
}

# Unhealthy Host Alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.environment_name}-unhealthy-hosts"
  alarm_description   = "Alert when there are unhealthy targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.api.arn_suffix
  }

  tags = {
    Name        = "${var.environment_name}-unhealthy-hosts"
    Environment = var.environment_name
  }
}

# High Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  alarm_name          = "${var.environment_name}-high-response-time"
  alarm_description   = "Alert when response time exceeds 500ms"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0.5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name        = "${var.environment_name}-high-response-time"
    Environment = var.environment_name
  }
}
