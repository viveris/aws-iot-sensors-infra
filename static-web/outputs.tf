output "web_bucket_id" {
  value = aws_s3_bucket.web.id
}

output "web_url" {
  value = "https://${aws_s3_bucket_website_configuration.web.website_endpoint}"
}
