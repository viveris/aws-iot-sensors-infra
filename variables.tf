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
