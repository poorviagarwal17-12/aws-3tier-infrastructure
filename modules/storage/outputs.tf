output "bucket_id" {
  description = "Name of the workspace S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the workspace S3 bucket"
  value       = aws_s3_bucket.this.arn
}
