output "bucket_name" {
  value = aws_s3_bucket.incident_bucket.bucket
}

output "sns_topic_arn" {
  value = aws_sns_topic.incident_alerts.arn
}

output "api_endpoint" {
  value = aws_apigatewayv2_stage.prod.invoke_url
}