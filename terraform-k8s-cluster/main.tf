terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "kubernetes" {
  config_path = var.kube_config_path
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_path
  }
}

module "nginx" {
  source          = "../terraform-apps/nginx"
  kube_config_path = var.kube_config_path
}

resource "kubernetes_namespace" "nginx-k8s" {
  metadata {
    name = "nginx-k8s"
  }
}

