#!/usr/bin/env bash
# Обёртка над официальным образом hashicorp/terraform.
# releases.hashicorp.com заблокирован для региона, поэтому CLI запускается
# из Docker-образа; сокет Docker пробрасывается внутрь, чтобы провайдер
# kreuzwerker/docker мог управлять контейнерами хоста.
#
# Использование:  ./scripts/tf.sh [-w каталог] <команда terraform>
#   пример:       ./scripts/tf.sh -w tutorials/03-build init
set -euo pipefail

export MSYS_NO_PATHCONV=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINPATH="$(cygpath -w "$ROOT")"

WORKDIR="."
if [ "${1:-}" = "-w" ]; then
  WORKDIR="$2"
  shift 2
fi

# Пробрасываем внутрь контейнера переменные окружения Terraform (TF_VAR_*, TF_LOG и т. п.),
# иначе они не видны процессу terraform, запущенному через docker run.
ENVARGS=()
for name in $(env | grep -oE '^(TF_VAR_|TF_LOG)[A-Za-z0-9_]*'); do
  ENVARGS+=(-e "$name")
done

exec docker run --rm -i \
  -v //var/run/docker.sock:/var/run/docker.sock \
  -v "${WINPATH}:/workspace" \
  -w "/workspace/${WORKDIR}" \
  -e TF_CLI_CONFIG_FILE=/workspace/terraform.tfrc \
  -e CHECKPOINT_DISABLE=1 \
  -e TF_IN_AUTOMATION="${TF_IN_AUTOMATION:-1}" \
  "${ENVARGS[@]}" \
  hashicorp/terraform:1.9.8 "$@"
