variable "project_name" {
  description = "Project name."
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

variable "table_basename" {
  description = "Base name of DynamoDB table in which to store the sensors measurements."
  type        = string
}

variable "topic_rule_sql_query" {
  description = "SQL query for the topic rule."
  type        = string
}

variable "topic_rule_device_value" {
  description = "Value to store as the hash key.  This should be a selector returning the device ID extracted from the MQTT topic."
  type        = string
}

variable "logs_bucket_name" {
  description = "Name of S3 bucket in which to put logs."
  type        = string
}

variable "iot_sensors_logger_role_arn" {
  description = "ARN of IAM role to assume in order to put logs in the logs bucket."
  type        = string
}
