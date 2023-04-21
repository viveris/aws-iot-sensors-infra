variable "project_name" {
  description = "Project name"
  type        = string
}

variable "region" {
  description = "AWS region to which resources are deployed."
  type        = string
}

variable "random_suffix" {
  description = "Random suffix to use in resource names."
  type        = string
}

variable "measurements_groups" {
  description = <<EOF
    Measurements groups.
    
    Each key-value pair of the map corresponds to a measurements group and creates an API Gateway endpoint that allows
    to query a specific DynamoDB table.

    Format is the following:

    {
      <url_path_group_1> = {
        table_name = <dynamodb_table_name_1>
        table_basename = <dynamodb_table_basename_1>
        table_arn = <dynamodb_table_base_arn_1>
      },
      ...
    }

  EOF

  type = map(map(any))
}
