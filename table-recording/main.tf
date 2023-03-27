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

  ttl {
    attribute_name = "ttl"
    enabled        = true
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


###################################################
# Lambda function that writes an item to DynamoDB #
###################################################

data "archive_file" "lambda" {
  type        = "zip"
  source_dir = var.record_item_lambda_src_path
  output_path = "lambda_function_${var.table_basename}.zip"
}

resource "aws_lambda_function" "record_item" {
  filename      = "lambda_function_${var.table_basename}.zip"
  function_name = "SensorsMessagesTo${var.table_basename}TableLambda"
  role          = aws_iam_role.sensors_table_writer.arn
  handler       = "index.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs18.x"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.sensors_table.name
      RECORD_TTL = var.dynamodb_item_ttl
    }
  }
}


# Role associated to Lambda function so that it can write to DynamoDB.

resource "aws_iam_role" "sensors_table_writer" {
  name = "${var.table_basename}Writer-${var.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
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

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy_to_role" {
  role       = aws_iam_role.sensors_table_writer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Permission configured in the Lambda function so that the IoT rule can invoke the function.

resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowExecutionFromIot"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.record_item.function_name
  principal     = "iot.amazonaws.com"
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

  lambda {
    function_arn = aws_lambda_function.record_item.arn
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
