output "alb_5xx_alarm_arn" {
  description = "ARN of ALB 5xx CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx_errors.arn
}

output "asg_cpu_alarm_arn" {
  description = "ARN of ASG high CPU CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.asg_cpu_high.arn
}

output "scale_out_policy_arn" {
  description = "ARN of Auto Scaling scale-out policy"
  value       = aws_autoscaling_policy.scale_out.arn
}
