terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_path
  }
}

resource "helm_release" "nginx" {
  name      = "nginx"
  chart     = "../terraform-apps/nginx/nginx-chart"  # Path to your local Helm chart
  version   = "1.16.0"          # Adjust the version if needed

  set {
    name  = "service.type"
    value = "NodePort"
  }
}

