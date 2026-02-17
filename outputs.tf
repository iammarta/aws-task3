output "s3_website_url" {
  description = "The public URL of the static website"
  value       = "http://${aws_s3_bucket_website_configuration.website_config.website_endpoint}"
}

output "pipeline_arn" {
  description = "The ARN of the CodePipeline"
  value       = aws_codepipeline.static_web_pipeline.arn
}