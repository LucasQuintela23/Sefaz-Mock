output "namespace" {
  description = "Namespace Kubernetes onde WireMock foi provisionado"
  value       = kubernetes_namespace.sefaz_mock.metadata[0].name
}

output "wiremock_service_name" {
  description = "Nome do Service do WireMock"
  value       = kubernetes_service.wiremock.metadata[0].name
}

output "wiremock_service_dns" {
  description = "FQDN interno do WireMock (para usar dentro do cluster)"
  value       = "${kubernetes_service.wiremock.metadata[0].name}.${kubernetes_namespace.sefaz_mock.metadata[0].name}.svc.cluster.local"
}

output "wiremock_deployment_name" {
  description = "Nome do Deployment do WireMock"
  value       = kubernetes_deployment.wiremock.metadata[0].name
}

output "next_steps" {
  description = "Próximos passos para conectar aos testes"
  value       = <<-EOT
    1. Aguardar readiness do WireMock:
       kubectl -n ${kubernetes_namespace.sefaz_mock.metadata[0].name} wait --for=condition=available deploy/${kubernetes_deployment.wiremock.metadata[0].name} --timeout=120s

    2. Fazer port-forward para 127.0.0.1:18080:
       kubectl -n ${kubernetes_namespace.sefaz_mock.metadata[0].name} port-forward svc/${kubernetes_service.wiremock.metadata[0].name} 18080:8080

    3. Em outro terminal, rodar testes:
       cd /home/quintela/projetos/osf-pocs/Sefaz-Mock
       SEFAZ_API_URL=http://127.0.0.1:18080 npx playwright test --reporter=line

    4. Verificar logs do WireMock:
       kubectl -n ${kubernetes_namespace.sefaz_mock.metadata[0].name} logs -f deploy/${kubernetes_deployment.wiremock.metadata[0].name}
  EOT
}
