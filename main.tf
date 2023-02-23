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

resource "aws_dynamodb_table" "sensor_measurements_table" {
  name         = "${var.sensors_measurements_table_basename}-${random_id.env_id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "timestamp"
  range_key    = "device"

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "device"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_policy" "write_to_table" {
  name        = "${var.sensors_measurements_table_basename}PutItem-${random_id.env_id.hex}"
  description = "Allow to put items in the DynamoDB table for sensors measurements"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.sensor_measurements_table.arn
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role" "sensor_measurements_table_writer" {
  name = "${var.sensors_measurements_table_basename}Writer-${random_id.env_id.hex}"

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

resource "aws_iam_role_policy_attachment" "attach_writer_policy_to_role" {
  role       = aws_iam_role.sensor_measurements_table_writer.name
  policy_arn = aws_iam_policy.write_to_table.arn
}

resource "aws_iot_topic_rule" "write_to_table" {
  name        = "SensorMessagesToDynamoDbTable_${random_id.env_id.hex}"
  description = "Writes sensor measurements published on specific topics to the measurements DynamoDB table"
  enabled     = true
  sql         = "SELECT temperature, humidity, barometer, wind.velocity as wind_velocity, wind.bearing as wind_bearing FROM 'device/+/data'"
  sql_version = "2016-03-23"

  dynamodb {
    hash_key_field = "timestamp"
    hash_key_type  = "NUMBER"
    hash_key_value = "$${timestamp()}"

    range_key_field = "device"
    range_key_type  = "STRING"
    # We get the device ID from MQTT topic as there is no way to get it from a SQL function.
    range_key_value = "$${cast(topic(2) AS DECIMAL)}"

    payload_field = "payload"

    operation = "INSERT"

    role_arn = aws_iam_role.sensor_measurements_table_writer.arn

    table_name = aws_dynamodb_table.sensor_measurements_table.name
  }

  tags = {
    Project = var.project_name
  }
}
