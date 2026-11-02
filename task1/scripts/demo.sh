#!/usr/bin/env bash
# Сквозной прогон всех руководств Terraform "Get Started - Docker".
# Результаты каждой команды сохраняются в evidence/NN-*.txt.
#
# Запуск:  bash scripts/demo.sh
# Требования: Docker, свободные порты 8000 и 8080, образы hashicorp/terraform:1.9.8,
#             nginx:1.27-alpine (см. README).
set -uo pipefail
export MSYS_NO_PATHCONV=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

W=learn-terraform-docker-container
LOG=""

mkdir -p tutorials/03-build tutorials/04-change tutorials/05-destroy \
         tutorials/06-variables tutorials/07-outputs

section() {
  echo
  echo "# $*"
}

run() {
  local cmd="$1"; shift
  echo
  echo "\$ $cmd"
  "$@" 2>&1
}

apply_yes() {
  echo "\$ bash scripts/tf.sh -w $W $*"
  echo yes | bash scripts/tf.sh -w "$W" "$@" -no-color 2>&1
}

# --- Подготовка рабочего каталога (как в руководстве) -------------------------
rm -rf "$W/.terraform" "$W/.terraform.lock.hcl" "$W/terraform.tfstate" \
       "$W/terraform.tfstate.backup" "$W/terraform.tfvars" "$W/variables.tf" "$W/outputs.tf"
mkdir -p "$W"

cat > "$W/main.tf" <<'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.2.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "tutorial"
  ports {
    internal = 80
    external = 8000
  }
}
EOF

# --- Шаг 2: Install Terraform -------------------------------------------------
{
  echo '# Шаг 2. Install Terraform — проверка установки и quick start'
  run "bash scripts/tf.sh version" bash scripts/tf.sh version
  run "bash scripts/tf.sh -w $W init" bash scripts/tf.sh -w "$W" init -no-color
  apply_yes apply
  run 'curl -s http://localhost:8000/ | grep -o "<title>[^<]*</title>"' \
      bash -c 'curl.exe -s http://localhost:8000/ | grep -o "<title>[^<]*</title>"'
  run "docker ps --filter name=tutorial" \
      docker ps --filter name=tutorial --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
  section "очистка после шага 2"
  apply_yes destroy
} > evidence/02-install.txt 2>&1

# --- Шаг 3: Build infrastructure ---------------------------------------------
{
  echo '# Шаг 3. Build infrastructure'
  run "bash scripts/tf.sh -w $W init" bash scripts/tf.sh -w "$W" init -no-color
  run "bash scripts/tf.sh -w $W fmt" bash scripts/tf.sh -w "$W" fmt
  run "bash scripts/tf.sh -w $W fmt -check" bash scripts/tf.sh -w "$W" fmt -check
  run "bash scripts/tf.sh -w $W validate" bash scripts/tf.sh -w "$W" validate -no-color
  run "bash scripts/tf.sh -w $W plan" bash scripts/tf.sh -w "$W" plan -no-color
  apply_yes apply
  run "bash scripts/tf.sh -w $W show" bash scripts/tf.sh -w "$W" show -no-color
  run "bash scripts/tf.sh -w $W state list" bash scripts/tf.sh -w "$W" state list
  run "docker ps --filter name=tutorial" \
      docker ps --filter name=tutorial --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
  run 'curl -s http://localhost:8000/ | grep -o "<title>[^<]*</title>"' \
      bash -c 'curl.exe -s http://localhost:8000/ | grep -o "<title>[^<]*</title>"'
} > evidence/03-build.txt 2>&1

cp "$W/main.tf" tutorials/03-build/main.tf

# --- Шаг 4: Change infrastructure --------------------------------------------
{
  echo '# Шаг 4. Change infrastructure: внешний порт 8000 -> 8080'
  echo
  echo '# изменение конфигурации:'
  echo '$ sed -i "s/external = 8000/external = 8080/" main.tf'
  echo '$ grep -A3 "ports {" main.tf'
} > evidence/04-change.txt 2>&1

sed -i 's/external = 8000/external = 8080/' "$W/main.tf"
{
  grep -A3 'ports {' "$W/main.tf"
  run "bash scripts/tf.sh -w $W plan" bash scripts/tf.sh -w "$W" plan -no-color
  apply_yes apply
  run "docker ps --filter name=tutorial" \
      docker ps --filter name=tutorial --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
  run 'curl -s http://localhost:8080/ | grep -o "<title>[^<]*</title>"' \
      bash -c 'curl.exe -s http://localhost:8080/ | grep -o "<title>[^<]*</title>"'
} >> evidence/04-change.txt 2>&1

cp "$W/main.tf" tutorials/04-change/main.tf

# --- Шаг 5: Destroy infrastructure -------------------------------------------
{
  echo '# Шаг 5. Destroy infrastructure'
  run "bash scripts/tf.sh -w $W destroy" bash scripts/tf.sh -w "$W" destroy -no-color -auto-approve
  run "docker ps -a --filter name=tutorial" \
      docker ps -a --filter name=tutorial --format "table {{.Names}}\t{{.Status}}"
  run "bash scripts/tf.sh -w $W state list" bash scripts/tf.sh -w "$W" state list
} > evidence/05-destroy.txt 2>&1

cp "$W/main.tf" tutorials/05-destroy/main.tf

# --- Шаг 6: Define input variables -------------------------------------------
rm -f "$W/terraform.tfvars" "$W/outputs.tf"

cat > "$W/variables.tf" <<'EOF'
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
EOF

cat > "$W/main.tf" <<'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.2.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = var.container_name
  ports {
    internal = 80
    external = var.external_port
  }
}
EOF

{
  echo '# Шаг 6. Define input variables'
  echo
  echo '$ cat variables.tf'
  cat "$W/variables.tf"
  run "bash scripts/tf.sh -w $W init" bash scripts/tf.sh -w "$W" init -no-color
  section "6.1 значение по умолчанию (tutorial, порт 8000)"
  apply_yes apply
  run "docker ps --filter name=tutorial" \
      docker ps --filter name=tutorial --format "table {{.Names}}\t{{.Ports}}"
  section "6.2 флаг -var"
  apply_yes apply -var "container_name=tutorial-var" -var "external_port=8082"
  run "docker ps --filter name=tutorial" \
      docker ps --filter name=tutorial --format "table {{.Names}}\t{{.Ports}}"
  section "6.3 переменная окружения TF_VAR_"
  echo '$ TF_VAR_container_name=tutorial-env TF_VAR_external_port=8083 bash scripts/tf.sh -w learn-terraform-docker-container apply'
  echo yes | TF_VAR_container_name=tutorial-env TF_VAR_external_port=8083 \
      bash scripts/tf.sh -w "$W" apply -no-color 2>&1
  run "docker ps --filter name=tutorial" \
      docker ps --filter name=tutorial --format "table {{.Names}}\t{{.Ports}}"
  section "6.4 файл terraform.tfvars (tutorial-tfvars, порт 8081)"
  cat > "$W/terraform.tfvars" <<'EOF'
container_name = "tutorial-tfvars"
external_port  = 8081
EOF
  echo '$ cat terraform.tfvars'
  cat "$W/terraform.tfvars"
  run "bash scripts/tf.sh -w $W plan" bash scripts/tf.sh -w "$W" plan -no-color
  apply_yes apply
  run "docker ps --filter name=tutorial" \
      docker ps --filter name=tutorial --format "table {{.Names}}\t{{.Ports}}"
} > evidence/06-variables.txt 2>&1

cp "$W/main.tf" tutorials/06-variables/main.tf
cp "$W/variables.tf" tutorials/06-variables/variables.tf
cp "$W/terraform.tfvars" tutorials/06-variables/terraform.tfvars

# --- Шаг 7: Query data with outputs ------------------------------------------
cat > "$W/outputs.tf" <<'EOF'
output "container_name" {
  description = "Имя созданного контейнера"
  value       = docker_container.nginx.name
}

output "container_id" {
  description = "ID созданного контейнера"
  value       = docker_container.nginx.id
}
EOF

{
  echo '# Шаг 7. Query data with outputs'
  echo
  echo '$ cat outputs.tf'
  cat "$W/outputs.tf"
  run "bash scripts/tf.sh -w $W apply" bash -c "echo yes | bash scripts/tf.sh -w $W apply -no-color"
  run "bash scripts/tf.sh -w $W output" bash scripts/tf.sh -w "$W" output
  run "bash scripts/tf.sh -w $W output container_name" bash scripts/tf.sh -w "$W" output container_name
  run "bash scripts/tf.sh -w $W output -json" bash scripts/tf.sh -w "$W" output -json
  run "bash scripts/tf.sh -w $W output -raw container_id" bash scripts/tf.sh -w "$W" output -raw container_id
  run "bash scripts/tf.sh -w $W output -raw container_id | xargs docker inspect --format '{{.Name}} {{.State.Status}}'" \
      bash -c "bash scripts/tf.sh -w $W output -raw container_id | tr -d '\r\n' | xargs docker inspect --format '{{.Name}} -> {{.State.Status}}'"
} > evidence/07-outputs.txt 2>&1

cp "$W/main.tf" tutorials/07-outputs/main.tf
cp "$W/variables.tf" tutorials/07-outputs/variables.tf
cp "$W/outputs.tf" tutorials/07-outputs/outputs.tf
cp "$W/terraform.tfvars" tutorials/07-outputs/terraform.tfvars

# --- финальная очистка --------------------------------------------------------
{
  echo '# Финальная очистка'
  apply_yes destroy
  run "docker ps -a --filter name=tutorial" \
      docker ps -a --filter name=tutorial --format "table {{.Names}}\t{{.Status}}"
} > evidence/08-cleanup.txt 2>&1

echo "готово: см. evidence/"
