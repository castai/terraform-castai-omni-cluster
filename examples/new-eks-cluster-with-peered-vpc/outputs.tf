output "image_registry_private_ip" {
  description = "Private IP of the image registry VM. Add this as an A record for your domain in Cloudflare."
  value       = aws_instance.image_registry.private_ip
}
