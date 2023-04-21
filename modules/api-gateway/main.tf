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


##############################
# Root measurements resource #
##############################

resource "aws_api_gateway_resource" "measurements" {
  rest_api_id = aws_api_gateway_rest_api.iot_sensors_api.id
  parent_id   = aws_api_gateway_rest_api.iot_sensors_api.root_resource_id
  path_part   = "measurements"
}


######################
# Measurements group #
######################

module "measurements_endpoint" {
  for_each = var.measurements_groups

  source = "../api-gateway-measurements-endpoint"

  project_name  = var.project_name
  region        = var.region
  random_suffix = var.random_suffix

  api_gateway_id               = aws_api_gateway_rest_api.iot_sensors_api.id
  api_gateway_root_resource_id = aws_api_gateway_resource.measurements.id
  table_name                   = each.value.table_name
  table_basename               = each.value.table_basename
  table_arn                    = each.value.table_arn
  measurements_group           = each.key
}
