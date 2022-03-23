output "db_detail" {
    value       = aws_db_instance.default.endpoint
    description = "Endpoint details of the database."
    sensitive   = false
}

