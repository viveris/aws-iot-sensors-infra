########################################################
# DynamoDB table in which to store sensor measurements #
########################################################

resource "aws_dynamodb_table" "sensors_table" {
  name             = "${var.project_name}-${var.table_basename}-${var.random_suffix}"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "OLD_IMAGE"
  hash_key         = "device"
  range_key        = "timestamp"

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

resource "aws_iam_policy" "allow_put_to_table" {
  name        = "${var.project_name}-AllowPutTo${var.table_basename}Table-${var.random_suffix}"
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

resource "aws_iam_policy" "allow_stream_processing" {
  name        = "${var.project_name}-Allow${var.table_basename}StreamProcessing-${var.random_suffix}"
  description = "Allows to process data from DynamoDB stream."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:ListStreams",
          "dynamodb:DescribeStream",
          "dynamodb:GetShardIterator",
          "dynamodb:GetRecords",
        ]
        Effect   = "Allow"
        Resource = "${aws_dynamodb_table.sensors_table.arn}/stream/*"
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

data "archive_file" "record_lambda" {
  type        = "zip"
  source_dir  = var.record_item_lambda_src_path
  output_path = "lambda_function_${var.table_basename}_record.zip"
}

resource "aws_lambda_function" "record_item" {
  filename      = data.archive_file.record_lambda.output_path
  function_name = "${var.project_name}-WriteMessageTo${var.table_basename}Table-${var.random_suffix}"
  role          = aws_iam_role.sensors_table_writer.arn
  handler       = "lambda_function.handler"

  source_code_hash = data.archive_file.record_lambda.output_base64sha256

  runtime = "python3.9"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.sensors_table.name
      RECORD_TTL = var.dynamodb_item_ttl
    }
  }

  tags = {
    Project = var.project_name
  }
}


# Role associated to Lambda function so that it can write to DynamoDB.

resource "aws_iam_role" "sensors_table_writer" {
  name = "${var.project_name}-${var.table_basename}TableWriter-${var.random_suffix}"

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

resource "aws_iam_role_policy_attachment" "attach_allow_put_to_table_policy_to_sensors_table_writer" {
  role       = aws_iam_role.sensors_table_writer.name
  policy_arn = aws_iam_policy.allow_put_to_table.arn
}

resource "aws_iam_role_policy_attachment" "attach_lambda_execution_role_policy_to_sensors_table_writer" {
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
  name        = "${var.project_name}_WriteTo${var.table_basename}Rule_${var.random_suffix}"
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
      key         = "${var.project_name}-WriteTo${var.table_basename}Rule_${var.random_suffix}.log"
      role_arn    = var.iot_sensors_logger_role_arn
    }
  }

  tags = {
    Project = var.project_name
  }
}


###############################################################
# S3 bucket in which to archive DynamoDB items deleted by TTL #
###############################################################

resource "aws_s3_bucket" "archive" {
  bucket = "${lower(var.project_name)}-${lower(var.table_basename)}-archive-${var.random_suffix}"

  tags = {
    Project = var.project_name
  }
}

# Create IoT service role with a policy allowing to write to the bucket.

resource "aws_iam_policy" "allow_write_to_archive" {
  name        = "${var.project_name}-AllowWriteTo${var.table_basename}Archive-${var.random_suffix}"
  description = "Allows to write to archive S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.archive.arn}/*"
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}


######################################################################################
# Kinesis Data Firehose that gets the data from Lambda processor and writes it to S3 #
######################################################################################

resource "aws_iam_role" "firehose" {
  name = "${var.project_name}-${var.table_basename}FirehoseRole-${var.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "attach_allow_write_to_archive_policy_to_firehose" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.allow_write_to_archive.arn
}

resource "aws_kinesis_firehose_delivery_stream" "s3_stream" {
  name        = "${var.project_name}-${var.table_basename}-${var.random_suffix}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.archive.arn

    buffer_size     = var.firehose_buffer_size
    buffer_interval = var.firehose_buffer_interval

    prefix              = "data/!{timestamp:yyyy}/!{timestamp:MM}/!{timestamp:dd}/!{timestamp:HH}/"
    error_output_prefix = "errors/!{timestamp:yyyy}/!{timestamp:MM}/!{timestamp:dd}/!{timestamp:HH}/!{firehose:error-output-type}/"
  }

  tags = {
    Project = var.project_name
  }
}

# Policy that allows to write data to the Kinesis Data Firehose

resource "aws_iam_policy" "allow_put_to_stream" {
  name        = "${var.project_name}-AllowPutTo${var.table_basename}Stream-${var.random_suffix}"
  description = "Allows to put records in the Firehose stream."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "firehose:PutRecordBatch",
        ]
        Effect   = "Allow"
        Resource = aws_kinesis_firehose_delivery_stream.s3_stream.arn
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}


#######################################################################
# Lambda function processing DynamoDB stream to archive deleted items #
#######################################################################

data "archive_file" "archive_deleted_lambda" {
  type        = "zip"
  source_dir  = "./lambda/archive_deleted"
  output_path = "lambda_function_${var.table_basename}_archive_deleted.zip"
}

resource "aws_lambda_function" "archive_deleted" {
  filename      = data.archive_file.archive_deleted_lambda.output_path
  function_name = "${var.project_name}-ArchiveDeleted${var.table_basename}Items-${var.random_suffix}"
  role          = aws_iam_role.dynamodb_stream_processor.arn
  handler       = "lambda_function.handler"

  source_code_hash = data.archive_file.archive_deleted_lambda.output_base64sha256

  runtime = "python3.9"

  environment {
    variables = {
      FIREHOSE_NAME = aws_kinesis_firehose_delivery_stream.s3_stream.name
      BATCH_SIZE    = var.dynamodb_stream_processing_lambda_batch_size
    }
  }

  tags = {
    Project = var.project_name
  }
}


# Role associated to Lambda function so that it can send data to Firehose

resource "aws_iam_role" "dynamodb_stream_processor" {
  name = "${var.project_name}-${var.table_basename}StreamProcessor-${var.random_suffix}"

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

resource "aws_iam_role_policy_attachment" "attach_lambda_execution_role_policy_to_dynamodb_stream_processor" {
  role       = aws_iam_role.dynamodb_stream_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "attach_allow_stream_processing_policy_to_dynamodb_stream_processor" {
  role       = aws_iam_role.dynamodb_stream_processor.name
  policy_arn = aws_iam_policy.allow_stream_processing.arn
}

resource "aws_iam_role_policy_attachment" "attach_allow_put_to_stream_policy_to_dynamodb_stream_processor" {
  role       = aws_iam_role.dynamodb_stream_processor.name
  policy_arn = aws_iam_policy.allow_put_to_stream.arn
}

# Permission configured in the Lambda function so that DynamoDB can invoke the function.

resource "aws_lambda_permission" "allow_dynamodb" {
  statement_id  = "AllowExecutionFromDynamodb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.archive_deleted.function_name
  principal     = "dynamodb.amazonaws.com"
}

# Lambda trigger

resource "aws_lambda_event_source_mapping" "archive_deleted_on_sensors_table_stream_event" {
  event_source_arn                   = aws_dynamodb_table.sensors_table.stream_arn
  function_name                      = aws_lambda_function.archive_deleted.arn
  starting_position                  = "LATEST"
  batch_size                         = 10
  maximum_batching_window_in_seconds = 0
}
