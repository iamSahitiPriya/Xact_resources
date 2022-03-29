output "db_detail" {
    value       = aws_db_instance.xact-db.endpoint
    description = "Endpoint details of the database."
    sensitive   = false
}

