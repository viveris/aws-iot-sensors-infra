#########################################################
# API Gateway execution role allowing to query DynamoDB #
#########################################################

resource "aws_iam_policy" "allow_query_tables" {
  name        = "${var.project_name}-AllowQueryTables-${var.random_suffix}"
  description = "Allow to query IOT sensors DynamoDB tables."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowQueryTables",
        Effect = "Allow",
        Action = [
          "dynamodb:Query"
        ],
        Resource = [
          var.motion_table_arn,
        ],
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role" "api_gateway" {
  name = "${var.project_name}-ApiGatewayRole-${var.random_suffix}"

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

resource "aws_iam_role_policy_attachment" "attach_allow_query_tables_policy_to_api_gateway" {
  role       = aws_iam_role.api_gateway.name
  policy_arn = aws_iam_policy.allow_query_tables.arn
}


####################
# Gateway API base #
####################

resource "aws_api_gateway_rest_api" "iot_sensors_api" {
  name        = "${var.project_name}-${var.random_suffix}"
  description = "Proxy REST API to IOT Sensors DynamoDB tables."
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}



####################
# Nested resources #
####################

resource "aws_api_gateway_resource" "measurements" {
  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id
  parent_id   = aws_api_gateway_rest_api.iot_sensors_api.root_resource_id
  path_part   = "measurements"
}

resource "aws_api_gateway_resource" "motion_measurements" {
  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id
  parent_id   = aws_api_gateway_resource.measurements.id
  path_part   = "motion"
}

resource "aws_api_gateway_resource" "device_motion_measurements" {
  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id
  parent_id   = aws_api_gateway_resource.motion_measurements.id
  path_part   = "{device}"
}

resource "aws_api_gateway_resource" "recent_device_motion_measurements" {
  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id
  parent_id   = aws_api_gateway_resource.device_motion_measurements.id
  path_part   = "recent"
}


########################
# Method configuration #
########################

resource "aws_api_gateway_method" "get_recent_device_motion_measurements" {
  rest_api_id   = aws_api_gateway_rest_api.iot_sensors_api.id
  resource_id   = aws_api_gateway_resource.recent_device_motion_measurements.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_recent_device_motion_measurements" {
  rest_api_id             = aws_api_gateway_rest_api.iot_sensors_api.id
  resource_id             = aws_api_gateway_resource.recent_device_motion_measurements.id
  http_method             = aws_api_gateway_method.get_recent_device_motion_measurements.http_method
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
    "TableName": "${var.motion_table_name}",
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

resource "aws_api_gateway_method_response" "get_recent_device_motion_measurements_200" {
  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id
  resource_id = aws_api_gateway_resource.recent_device_motion_measurements.id
  http_method = aws_api_gateway_method.get_recent_device_motion_measurements.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "get_recent_device_motion_measurements" {
  depends_on = [
    aws_api_gateway_integration.get_recent_device_motion_measurements,
  ]

  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id
  resource_id = aws_api_gateway_resource.recent_device_motion_measurements.id
  http_method = aws_api_gateway_method.get_recent_device_motion_measurements.http_method
  status_code = aws_api_gateway_method_response.get_recent_device_motion_measurements_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET'"
  }
}


##############
# Deployment #
##############

resource "aws_api_gateway_deployment" "v1" {
  depends_on = [
    aws_api_gateway_method.get_recent_device_motion_measurements,
    aws_api_gateway_integration.get_recent_device_motion_measurements,
    aws_api_gateway_integration_response.get_recent_device_motion_measurements,
  ]

  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id

  triggers = {
    redeployment = sha1(jsonencode({
      api_gateway = file("${path.module}/main.tf"),
      motion_table_name = var.motion_table_name,
      motion_table_arn = var.motion_table_arn,
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  deployment_id = aws_api_gateway_deployment.v1.id
  rest_api_id   = aws_api_gateway_rest_api.iot_sensors_api.id
  stage_name    = "v1"
}
