variable "project_name" {
  description = "Base project name"
  type        = string
}

variable "environment" {
  description = "Environment name (workspace)"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class (Free Tier eligible: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "dbadmin"
}

variable "db_subnet_group_name" {
  description = "Name of DB subnet group spanning private subnets"
  type        = string
}

variable "db_security_group_id" {
  description = "Security group ID for RDS instance"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection on RDS"
  type        = bool
  default     = false
}
