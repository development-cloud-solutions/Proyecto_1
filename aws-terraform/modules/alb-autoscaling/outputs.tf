# =============================================================================
# ANB Rising Stars - ALB/ASG Module Outputs
# =============================================================================

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.api.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.api.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.api.id
}
