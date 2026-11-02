#!/usr/bin/env bash
# Скачивает провайдер kreuzwerker/docker в локальное зеркало .plugins/
# (реестр registry.terraform.io недоступен из региона, поэтому provider
# берётся из релизов GitHub и подключается через terraform.tfrc).
set -euo pipefail

VERSION="${1:-4.2.0}"
PLATFORM="linux_amd64"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/.plugins/registry.terraform.io/kreuzwerker/docker"
FILE="terraform-provider-docker_${VERSION}_${PLATFORM}.zip"

mkdir -p "$DIR"
if [ -f "$DIR/$FILE" ]; then
  echo "уже есть: $DIR/$FILE"
  exit 0
fi

URL="https://github.com/kreuzwerker/terraform-provider-docker/releases/download/v${VERSION}/${FILE}"
echo "скачиваю $URL"
curl -L --fail --progress-bar -o "$DIR/$FILE" "$URL"
ls -lh "$DIR/$FILE"
