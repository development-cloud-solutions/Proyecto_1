# =============================================================================
# ANB Rising Stars - Workers Module Outputs
# =============================================================================

output "autoscaling_group_name" {
  description = "Name of the Worker Auto Scaling Group"
  value       = aws_autoscaling_group.worker.name
}

output "launch_template_id" {
  description = "ID of the Worker Launch Template"
  value       = aws_launch_template.worker.id
}
