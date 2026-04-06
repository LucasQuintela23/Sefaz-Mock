terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# Namespace para recursos de teste
resource "kubernetes_namespace" "sefaz_mock" {
  metadata {
    name   = var.namespace
    labels = {
      app     = "sefaz-mock"
      version = "1.0.0"
    }
  }
}

# ConfigMap com mapeamentos do WireMock
resource "kubernetes_config_map" "wiremock_mappings" {
  metadata {
    name      = "wiremock-mappings"
    namespace = kubernetes_namespace.sefaz_mock.metadata[0].name
  }

  # Lê todos os arquivos JSON de mappings locais
  data = {
    for file in fileset("${var.mappings_dir}", "*.json") :
    file => file("${var.mappings_dir}/${file}")
  }

  depends_on = [kubernetes_namespace.sefaz_mock]
}

# Deployment do WireMock
resource "kubernetes_deployment" "wiremock" {
  metadata {
    name      = "wiremock"
    namespace = kubernetes_namespace.sefaz_mock.metadata[0].name
    labels = {
      app = "wiremock"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wiremock"
      }
    }

    template {
      metadata {
        labels = {
          app = "wiremock"
        }
      }

      spec {
        container {
          image = var.wiremock_image
          name  = "wiremock"

          port {
            container_port = 8080
            name           = "http"
          }

          env {
            name  = "WIREMOCK_OPTS"
            value = "--verbose --port 8080"
          }

          volume_mount {
            name       = "wiremock-mappings"
            mount_path = "/home/wiremock/mappings"
            read_only  = true
          }

          readiness_probe {
            http_get {
              path   = "/__admin/health"
              port   = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "wiremock-mappings"
          config_map {
            name = kubernetes_config_map.wiremock_mappings.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.sefaz_mock,
    kubernetes_config_map.wiremock_mappings
  ]
}

# Service para expor WireMock internamente
resource "kubernetes_service" "wiremock" {
  metadata {
    name      = "wiremock"
    namespace = kubernetes_namespace.sefaz_mock.metadata[0].name
    labels = {
      app = "wiremock"
    }
  }

  spec {
    selector = {
      app = "wiremock"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.sefaz_mock]
}
