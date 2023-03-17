terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.55"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "random_id" "env_id" {
  byte_length = 4
}


##################
# Logging bucket #
##################

resource "aws_s3_bucket" "logs" {
  bucket = "iot-sensors-logs-${random_id.env_id.hex}"

  tags = {
    Project = var.project_name
  }
}

# Create IoT service role with a policy allowing to write to the bucket.

resource "aws_iam_policy" "write_logs" {
  name        = "IotSensorsWriteLogs-${random_id.env_id.hex}"
  description = "Allow write access to the logs S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.logs.arn}/*"
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role" "iot_sensors_logger" {
  name = "IotSensorsLogger-${random_id.env_id.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "attach_write_logs_to_iot_sensors_logger" {
  role       = aws_iam_role.iot_sensors_logger.name
  policy_arn = aws_iam_policy.write_logs.arn
}


###############################################################
# Resources to record motion sensors data to a DynamoDB table #
###############################################################

module "motion_table_recording" {
  source = "./table-recording"

  project_name  = var.project_name
  region        = var.region
  random_suffix = random_id.env_id.hex

  table_basename              = "MotionMeasurementsTable"
  topic_rule_sql_query        = "SELECT acceleration_mG.x as acceleration_mG_x, acceleration_mG.y as acceleration_mG_y, acceleration_mG.z as acceleration_mG_z, gyro_mDPS.x as gyro_mDPS_x, gyro_mDPS.y as gyro_mDPS_y, gyro_mDPS.z as gyro_mDPS_z, magnetometer_mGauss.x as magnetometer_mGauss_x, magnetometer_mGauss.y as magnetometer_mGauss_y, magnetometer_mGauss.z as magnetometer_mGauss_z FROM '+/motion_sensor_data'"
  topic_rule_device_value     = "$${topic(1)}"
  logs_bucket_name            = aws_s3_bucket.logs.id
  iot_sensors_logger_role_arn = aws_iam_role.iot_sensors_logger.arn
}


###############
# API Gateway #
###############

module "api_gateway" {
  source = "./api-gateway"

  project_name  = var.project_name
  region        = var.region
  random_suffix = random_id.env_id.hex

  motion_table_name = module.motion_table_recording.sensors_table_name
  motion_table_arn  = module.motion_table_recording.sensors_table_arn
}
