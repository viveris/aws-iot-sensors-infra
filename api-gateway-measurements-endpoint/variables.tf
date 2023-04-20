variable "project_name" {
  description = "Project name"
  type        = string
}

variable "region" {
  description = "AWS region to which resources are deployed."
  type        = string
}

variable "random_suffix" {
  description = "Random suffix to use in resource names."
  type        = string
}

variable "api_gateway_id" {
  description = "ID of the API Gateway in which to attach new subresources."
  type        = string
}

variable "api_gateway_root_resource_id" {
  description = "ID of the API Gateway root resource to which to attach subresources."
  type        = string
}

variable "table_name" {
  description = "Name of the DynamoDB table to query when making requests to the API Gateway subresources."
  type        = string
}

variable "table_basename" {
  description = "Basename of the DynamoDB table to query when making requests to the API Gateway subresources."
  type        = string
}

variable "table_arn" {
  description = "ARN of the DynamoDB table to query when making requests to the API Gateway subresources."
  type        = string
}

variable "measurements_group" {
  description = "Name of measurements group to use in the API Gateway URL path to identify the measurements in the DynamoDB table."
  type        = string
}
