# Лабораторная работа №5

Проектирование модели управления версиями ПО, конфигурациями и непрерывной поставкой.
Дисциплина «Непрерывное интегрирование и сборка программного обеспечения», ФПМИ БГУ.

# Overview

Выполняется вариант для **группы 13 — задания 1 и 2** (задание 3 предназначено для групп 10–12).

| Задание | Каталог | Содержание | Статус |
|---------|---------|------------|--------|
| Задание 1. Основы управления конфигурацией инфраструктуры с Terraform | [`task1/`](task1/) | все 7 руководств Terraform «Get Started — Docker»: создание, изменение, удаление инфраструктуры, переменные, outputs | выполнено |
| Задание 2. Управление конфигурацией серверов с помощью Ansible | [`task2/`](task2/) | инвентарь, ad-hoc команды, CLI-инструменты, playbooks, идемпотентность, примеры из руководства | выполнено |
| Задание 3. Создание кластера с помощью Terraform и Ansible | — | не выполняется для группы 13 | — |

# Usage

Отчёт по лабораторной работе: [`docs/report.md`](docs/report.md) — в нём цель работы,
вариант задания, код конфигурационных файлов обоих заданий, результаты выполнения
и ответы на 18 контрольных вопросов.

Исходные файлы задания 1 и инструкция по воспроизведению:

* [`task1/README.md`](task1/README.md) — прохождение всех 7 руководств с реальным выводом команд;
* [`task1/scripts/tf.sh`](task1/scripts/tf.sh) — обёртка запуска Terraform (bash);
* [`task1/scripts/tf.ps1`](task1/scripts/tf.ps1) — то же для Windows PowerShell;
* [`task1/scripts/demo.sh`](task1/scripts/demo.sh) — сквозной прогон всех шагов;
* [`task1/evidence/`](task1/evidence/) — сохранённый вывод каждой команды.

Исходные файлы задания 2 и инструкция по воспроизведению:

* [`task2/README.md`](task2/README.md) — инвентарь, ad-hoc команды, CLI-инструменты, 4 playbook, роль компонентов, реальный вывод;
* [`task2/inventory/hosts.yml`](task2/inventory/hosts.yml) — инвентарь с группами и подключением `community.docker.docker`;
* [`task2/playbooks/`](task2/playbooks/) — playbook (подготовка узлов, веб-сервер, факты, пример из руководства);
* [`task2/scripts/ansible.sh`](task2/scripts/ansible.sh) / [`ansible.ps1`](task2/scripts/ansible.ps1) — обёртки запуска (bash / PowerShell);
* [`task2/scripts/demo.sh`](task2/scripts/demo.sh) — сквозной прогон всех 9 шагов;
* [`task2/evidence/`](task2/evidence/) — сохранённый вывод каждой команды (01…09).

Быстрый запуск задания 1:

```bash
cd task1
bash scripts/fetch-provider.sh 4.2.0
docker pull hashicorp/terraform:1.9.8 && docker pull nginx:1.27-alpine
bash scripts/demo.sh
```

Быстрый запуск задания 2 (нужен запущенный кластер `kind` из лабораторной работы №4):

```bash
cd task2
docker build -t lab5-ansible:1.0 .
bash scripts/demo.sh
```

# Author

Цзэн Яосинь (ZENG YAOXIN), студент группы 13, ФПМИ БГУ.

# Additional Notes

Особенности окружения:

* с нашего IP-адреса `releases.hashicorp.com` и `registry.terraform.io` возвращают
  «Content not available in your region». Поэтому Terraform CLI берётся из официального
  Docker-образа, а провайдер `kreuzwerker/docker` — из релизов GitHub и подключается
  локальным файловым зеркалом (`task1/terraform.tfrc`). Подробнее — в
  [task1/README.md](task1/README.md), раздел «Окружение»;
* Ansible не поддерживает Windows как управляющий узел, а WSL отключён политикой
  безопасности. Поэтому контрольный узел — контейнер `lab5-ansible:1.0`, а целевые
  узлы кластера `kind` (лабораторная работа №4) управляются плагином
  `community.docker.docker` через `docker exec`, без SSH. Минимальные образы kind не
  содержат python3, поэтому первый playbook ставит его модулем `raw`. Подробнее — в
  [task2/README.md](task2/README.md), раздел «Окружение».

Репозиторий курса: <!-- заменить на ссылку на свой репозиторий -->
# Continuous-integration-and-software-build_LAB5
