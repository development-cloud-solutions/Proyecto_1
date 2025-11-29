# =============================================================================
# ANB Rising Stars - SQS Module Outputs
# =============================================================================

output "queue_url" {
  description = "URL of the SQS Queue"
  value       = aws_sqs_queue.video_processing.url
}

output "queue_arn" {
  description = "ARN of the SQS Queue"
  value       = aws_sqs_queue.video_processing.arn
}

output "queue_name" {
  description = "Name of the SQS Queue"
  value       = aws_sqs_queue.video_processing.name
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}
