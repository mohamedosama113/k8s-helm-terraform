output "nginx_release_name" {
  description = "The name of the Helm release"
  value       = helm_release.nginx.name
}

output "nginx_release_status" {
  description = "The status of the Helm release"
  value       = helm_release.nginx.status
}


data "kubernetes_service" "nginx" {
  metadata {
    name      = helm_release.nginx.name
    namespace = helm_release.nginx.namespace
  }
}

