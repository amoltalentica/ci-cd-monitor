output "app_public_ip" {
  value = aws_instance.app.public_ip
  description = "Public IP to access the app"
}

output "app_public_dns" {
  value = aws_instance.app.public_dns
  description = "Public DNS name (if available)"
}
