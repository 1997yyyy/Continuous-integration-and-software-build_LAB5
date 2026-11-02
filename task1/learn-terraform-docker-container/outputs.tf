output "container_name" {
  description = "Имя созданного контейнера"
  value       = docker_container.nginx.name
}

output "container_id" {
  description = "ID созданного контейнера"
  value       = docker_container.nginx.id
}
