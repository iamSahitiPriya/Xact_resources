output "sonar-ip" {
    value = aws_instance.web.associate_public_ip_address
    description = "Public IP address associated with instance."
}
