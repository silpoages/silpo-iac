output "bucket_name" {
  description = "Name of the media bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the media bucket (pass to ecs-service's media_bucket_arn)."
  value       = aws_s3_bucket.this.arn
}
