variable "project_name" {
  description = "Project name."
  type        = string
  default     = "AwsIotSensors"
}

variable "region" {
  description = "AWS region to which resources are deployed."
  type        = string
  default     = "eu-west-3"
}

variable "dynamodb_item_ttl" {
  description = "TTL for items recorded in DynamoDB (s).  Items are moved to S3 after their TTL expires."
  type        = number
  default     = 2592000  # 30 days
}
