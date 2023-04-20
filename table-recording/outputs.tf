output "sensors_table_name" {
  value = aws_dynamodb_table.sensors_table.name
}

output "sensors_table_arn" {
  value = aws_dynamodb_table.sensors_table.arn
}
