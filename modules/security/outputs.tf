output "alb_security_group_id" {
  description = "Security Group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security Group ID for the Application EC2 instances"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security Group ID for the RDS Database"
  value       = aws_security_group.db.id
}

output "iam_instance_profile_name" {
  description = "IAM Instance Profile Name for Launch Template"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "iam_instance_profile_arn" {
  description = "IAM Instance Profile ARN for Launch Template"
  value       = aws_iam_instance_profile.ec2_instance_profile.arn
}

output "ec2_role_arn" {
  description = "IAM Role ARN attached to EC2 instances"
  value       = aws_iam_role.ec2_app_role.arn
}
