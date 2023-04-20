#########################################################
# API Gateway execution role allowing to query DynamoDB #
#########################################################

resource "aws_iam_policy" "allow_query_table" {
  name        = "${var.project_name}-AllowQuery${var.table_basename}-${var.random_suffix}"
  description = "Allow to query IOT sensors DynamoDB table ${var.table_name}."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowQueryTable",
        Effect = "Allow",
        Action = [
          "dynamodb:Query"
        ],
        Resource = var.table_arn,
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role" "api_gateway" {
  name = "${var.project_name}-ApiGateway${var.table_basename}Role-${var.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "attach_allow_query_table_policy_to_api_gateway" {
  role       = aws_iam_role.api_gateway.name
  policy_arn = aws_iam_policy.allow_query_table.arn
}


#######################
# Nested subresources #
#######################

resource "aws_api_gateway_resource" "measurements_group" {
  rest_api_id = var.api_gateway_id
  parent_id   = var.api_gateway_root_resource_id
  path_part   = var.measurements_group
}

resource "aws_api_gateway_resource" "measurements_group_device" {
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.measurements_group.id
  path_part   = "{device}"
}

resource "aws_api_gateway_resource" "measurements_group_device_recent" {
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.measurements_group_device.id
  path_part   = "recent"
}


#######################################################
# Recent measurements for device method configuration #
#######################################################

resource "aws_api_gateway_method" "get_recent_device_measurements" {
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.measurements_group_device_recent.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_recent_device_measurements" {
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.measurements_group_device_recent.id
  http_method             = aws_api_gateway_method.get_recent_device_measurements.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  credentials             = aws_iam_role.api_gateway.arn
  uri                     = "arn:aws:apigateway:${var.region}:dynamodb:action/Query"
  passthrough_behavior = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = <<EOF
#set($now = $context.requestTimeEpoch / 1000)
#set($start = $now - 300)
{
    "TableName": "${var.table_name}",
    "KeyConditionExpression": "device = :device AND #timestamp > :start",
    "ExpressionAttributeNames": { "#timestamp": "timestamp" },
    "ExpressionAttributeValues": {
        ":device": {
            "S": "$input.params('device')"
        },
        ":start": {
            "N": "$start"
        }
    }
}
EOF
  }
}

resource "aws_api_gateway_method_response" "get_recent_device_measurements_200" {
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.measurements_group_device_recent.id
  http_method = aws_api_gateway_method.get_recent_device_measurements.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "get_recent_device_measurements" {
  depends_on = [
    aws_api_gateway_integration.get_recent_device_measurements,
  ]

  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.measurements_group_device_recent.id
  http_method = aws_api_gateway_method.get_recent_device_measurements.http_method
  status_code = aws_api_gateway_method_response.get_recent_device_measurements_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET'"
  }
}
