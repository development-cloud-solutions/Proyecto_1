# =============================================================================
# ANB Rising Stars - SQS Module
# Equivalent to 03.5-sqs-queue.yaml
# =============================================================================

# -----------------------------------------------------------------------------
# Dead Letter Queue (DLQ) for failed messages
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.environment_name}-video-processing-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name        = "${var.environment_name}-video-processing-dlq"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# Main Video Processing Queue
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "video_processing" {
  name                       = "${var.environment_name}-video-processing"
  message_retention_seconds  = var.message_retention_period
  visibility_timeout_seconds = var.visibility_timeout
  receive_wait_time_seconds  = 20  # Long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name        = "${var.environment_name}-video-processing"
    Environment = var.environment_name
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

# Queue Depth High Alarm
resource "aws_cloudwatch_metric_alarm" "queue_depth_high" {
  alarm_name          = "${var.environment_name}-sqs-queue-depth-high"
  alarm_description   = "Alert when queue depth is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.video_processing.name
  }

  tags = {
    Name        = "${var.environment_name}-sqs-queue-depth-high"
    Environment = var.environment_name
  }
}

# Oldest Message Age Alarm
resource "aws_cloudwatch_metric_alarm" "message_age_high" {
  alarm_name          = "${var.environment_name}-sqs-message-age-high"
  alarm_description   = "Alert when oldest message age is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1800  # 30 minutes
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.video_processing.name
  }

  tags = {
    Name        = "${var.environment_name}-sqs-message-age-high"
    Environment = var.environment_name
  }
}

# DLQ Depth Alarm
resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.environment_name}-sqs-dlq-messages"
  alarm_description   = "Alert when messages appear in DLQ"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  tags = {
    Name        = "${var.environment_name}-sqs-dlq-messages"
    Environment = var.environment_name
  }
}
