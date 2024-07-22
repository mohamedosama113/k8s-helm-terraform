output "nginx_release_name" {
  description = "The name of the Nginx Helm release"
  value       = module.nginx.nginx_release_name
}

output "nginx_release_status" {
  description = "The status of the Nginx Helm release"
  value       = module.nginx.nginx_release_status
}
