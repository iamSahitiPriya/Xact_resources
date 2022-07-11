output "db_detail" {
    value       = aws_db_instance.xact-db_non_prod.endpoint
    description = "Endpoint details of the database."
    sensitive   = false
}

