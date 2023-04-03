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

variable "dynamodb_stream_processing_lambda_batch_size" {
  description = "Batch size (number of items) used to write items to the Firehose stream, when multiple records are received from DynamoDB by the Lambda function."
  type        = number
  default     = 400
}

variable "firehose_buffer_size" {
  description = "Size of buffer (in MB) for the Firehose delivery stream.  When the data in the stream reaches this size, data is delivered to S3."
  type        = number
  default     = 64
}

variable "firehose_buffer_interval" {
  description = "Buffer time interval (s) for the Firehose delivery stream.  The stream waits at most this time interval before delivering data to S3 (even if buffer size is not reached)."
  type        = number
  default     = 600
}
