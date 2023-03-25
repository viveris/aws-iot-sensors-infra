output "api_url" {
  value = module.api_gateway.api_url
}

output "web_bucket_id" {
  value = module.static_web.web_bucket_id
}

output "web_url" {
  value = module.static_web.web_url
}
