# =============================================================================
# ANB Rising Stars - SQS Module Variables
# =============================================================================

variable "environment_name" {
  description = "Environment name prefix"
  type        = string
}

variable "message_retention_period" {
  description = "Message retention period in seconds"
  type        = number
  default     = 345600  # 4 days
}

variable "visibility_timeout" {
  description = "Visibility timeout in seconds"
  type        = number
  default     = 900  # 15 minutes
}

variable "max_receive_count" {
  description = "Max receive count before sending to DLQ"
  type        = number
  default     = 3
}
