variable "project_name" {
  description = "Project name"
  type        = string
  default     = "AwsIotSensors"
}

variable "region" {
  description = "AWS region to which resources are deployed"
  type        = string
  default     = "eu-west-3"
}

variable "sensors_measurements_table_basename" {
  description = "DynamoDB table basename for the sensors measurements table"
  type        = string
  default     = "SensorMeasurementsTable"
}