output "api_url" {
  value = "https://${module.api_gateway.api_id}.execute-api.${data.aws_region.current.name}.amazonaws.com/v1"
}

output "web_bucket_id" {
  value = module.static_web.web_bucket_id
}

output "web_url" {
  value = module.static_web.web_url
}

output "deploy_command" {
  value = "aws apigateway create-deployment --rest-api-id ${module.api_gateway.api_id} --stage-name v1"
}
