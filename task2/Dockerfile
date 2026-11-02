# Контрольный узел Ansible.
#
# Ansible не поддерживает Windows как управляющую машину, а WSL в этой системе
# отключён политикой безопасности. Поэтому управляющий узел — контейнер:
# официальный образ alpine/ansible + docker-cli, который нужен подключаемому
# плагину community.docker.docker (он работает через `docker exec`).
FROM alpine/ansible:latest

RUN apk add --no-cache docker-cli openssh-client

WORKDIR /work
