variable "container_name" {
  description = "Имя Docker-контейнера"
  type        = string
  default     = "tutorial"
}

variable "external_port" {
  description = "Внешний порт, на который публикуется nginx"
  type        = number
  default     = 8000
}
