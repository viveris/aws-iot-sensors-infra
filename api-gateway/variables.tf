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

variable "motion_table_name" {
  description = "DynamoDB table name for motion sensors measurements."
  type        = string
}

variable "motion_table_arn" {
  description = "ARN of DynamoDB table for motion sensors measurements."
  type        = string
}
