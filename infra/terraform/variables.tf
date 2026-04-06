variable "kubeconfig_path" {
  type        = string
  description = "Caminho para kubeconfig local"
  default     = "~/.kube/config"
}

variable "namespace" {
  type        = string
  description = "Namespace para recursos de teste"
  default     = "sefaz-mock"
}

variable "wiremock_image" {
  type        = string
  description = "Imagem Docker do WireMock a usar"
  default     = "wiremock/wiremock:3.10.0"
}

variable "mappings_dir" {
  type        = string
  description = "Diretório com mapeamentos JSON do WireMock"
  default     = "../../mocks/mappings"
}
