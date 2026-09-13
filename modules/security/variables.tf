variable "project_name" {
  description = "Base project name"
  type        = string
}

variable "environment" {
  description = "Environment name (workspace)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 storage bucket for least-privilege read-only access"
  type        = string
}

variable "aws_region" {
  description = "AWS region for scoped Secrets Manager IAM access"
  type        = string
  default     = "us-east-1"
}

variable "db_port" {
  description = "Port used by the RDS database (default 3306 for MySQL)"
  type        = number
  default     = 3306
}
