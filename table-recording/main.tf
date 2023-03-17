########################################################
# DynamoDB table in which to store sensor measurements #
########################################################

resource "aws_dynamodb_table" "sensors_table" {
  name         = "${var.table_basename}-${var.random_suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device"
  range_key    = "timestamp"

  attribute {
    name = "device"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_policy" "write_to_table" {
  name        = "${var.table_basename}PutItem-${var.random_suffix}"
  description = "Allow to put items in the DynamoDB table for sensors measurements"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.sensors_table.arn
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role" "sensors_table_writer" {
  name = "${var.table_basename}Writer-${var.random_suffix}"

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

resource "aws_iam_role_policy_attachment" "writer_policy_to_role" {
  role       = aws_iam_role.sensors_table_writer.name
  policy_arn = aws_iam_policy.write_to_table.arn
}


##################################
# IoT message routing topic rule #
##################################

resource "aws_iot_topic_rule" "write_to_table" {
  name        = "SensorsMessagesTo${var.table_basename}Table_${var.random_suffix}"
  description = "Writes sensor measurements to the ${var.table_basename} DynamoDB table"
  enabled     = true
  sql         = var.topic_rule_sql_query
  sql_version = "2016-03-23"

  dynamodb {
    hash_key_field = "device"
    hash_key_type  = "STRING"
    # We get the device ID from MQTT topic as there is no way to get it from a SQL function.
    hash_key_value = var.topic_rule_device_value

    range_key_field = "timestamp"
    range_key_type  = "NUMBER"
    range_key_value = "$${timestamp()}"

    payload_field = "payload"

    operation = "INSERT"

    role_arn = aws_iam_role.sensors_table_writer.arn

    table_name = aws_dynamodb_table.sensors_table.name
  }


  # Log errors to S3.
  
  error_action {
    s3 {
      bucket_name = var.logs_bucket_name
      key = "SensorsMessagesTo${var.table_basename}Table.log"
      role_arn = var.iot_sensors_logger_role_arn
    }
  }

  tags = {
    Project = var.project_name
  }
}
