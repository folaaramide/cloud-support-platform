variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "eu-west-2"
}

variable "bucket_name" {
  description = "S3 bucket for incident storage"
  type        = string
}

variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
}
