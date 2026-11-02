#!/usr/bin/env bash
# Обёртка над управляющим узлом Ansible (образ lab5-ansible:1.0).
#
# Ansible не поддерживает Windows как управляющую машину, а WSL в этой системе
# отключён политикой безопасности, поэтому ansible / ansible-playbook /
# ansible-inventory запускаются в контейнере. Каталог задания монтируется
# в /work, сокет Docker — внутрь: подключаемый модуль community.docker.docker
# выполняет команды в узлах кластера kind через `docker exec`.
#
# Использование:  ./scripts/ansible.sh <команда> [аргументы]
#   примеры:      ./scripts/ansible.sh ansible k8s -m ansible.builtin.ping
#                 ./scripts/ansible.sh ansible-playbook playbooks/01-webserver.yml
#                 ./scripts/ansible.sh ansible-inventory --graph
set -euo pipefail

export MSYS_NO_PATHCONV=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINPATH="$(cygpath -w "$ROOT")"

if [ "$#" -eq 0 ]; then
  echo "usage: scripts/ansible.sh <ansible|ansible-playbook|ansible-inventory|...> [args]" >&2
  exit 1
fi

exec docker run --rm -i \
  -v //var/run/docker.sock:/var/run/docker.sock \
  -v "${WINPATH}:/work" \
  -w /work \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_FORCE_COLOR="${ANSIBLE_FORCE_COLOR:-0}" \
  -e ANSIBLE_HOST_KEY_CHECKING=False \
  lab5-ansible:1.0 "$@"
