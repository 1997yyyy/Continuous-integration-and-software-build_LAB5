# Отчёт по лабораторной работе №5

**Дисциплина:** «Непрерывное интегрирование и сборка программного обеспечения»

| | |
|---|---|
| **Выполнил** | Цзэн Яосинь (ZENG YAOXIN) |
| **Группа** | 13 |
| **Тема** | Проектирование модели управления версиями ПО, конфигурациями и непрерывной поставкой |
| **Задания** | 1–2 (для группы 13 задание 3 не выполняется) |
| **Репозиторий** | <!-- ссылка на репозиторий --> |

---

## 1. Цель работы

Изучение решений для автоматизации управления инфраструктурой и установки приложений:
освоить Terraform как инструмент «инфраструктура как код» (IaC) и Ansible как систему
управления конфигурацией серверов, а также продемонстрировать их совместное применение.

Задачи работы:

1. установить и изучить применение Terraform;
2. установить и изучить руководство по Ansible;
3. продемонстрировать развёртывание инфраструктуры и установку приложений с использованием
   Terraform и Ansible;
4. оформить отчёт в формате Markdown и создать Pull Request в git-репозитории.

## 2. Вариант задания

Согласно критериям оценивания, группы 10–12 выполняют задания 1–3, **группа 13 — задания 1–2**.
В отчёте представлены результаты обоих заданий: задание 1 (Terraform) — в каталоге
`task1/`, задание 2 (Ansible) — в каталоге `task2/`. Задание 3 не выполняется.

Текст задания 2 (п. «Управление конфигурацией серверов с помощью Ansible»):
изучить статьи *How To Set Up Ansible Inventories*, *How To Manage Multiple Servers
with Ansible Ad Hoc Commands*, документацию *Using Ansible command line tools*;
продемонстрировать подключение к узлам кластера Kubernetes и установку пакета (например
`zsh`) командами; изучить *How To Write Ansible Playbooks* и *Using Ansible playbooks*;
настроить конфигурации в виде playbook и продемонстрировать их; выполнить примеры из
руководства Ansible; опубликовать конфигурационные файлы в репозитории.
Отметим, что в методичке узлы отнесены к «лабораторной работе 3», фактически кластер
`kind` создан в лабораторной работе №4 — используются его узлы `lab4-*`.

## 3. Код приложений и конфигурационных файлов

### 3.1. Рабочее пространство Terraform

Каталог `task1/learn-terraform-docker-container` — то же имя, что в официальном руководстве.

`main.tf` (итоговое состояние после шага 6):

```hcl
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
```

`variables.tf` (шаг 6):

```hcl
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
```

`outputs.tf` (шаг 7):

```hcl
output "container_name" {
  description = "Имя созданного контейнера"
  value       = docker_container.nginx.name
}

output "container_id" {
  description = "ID созданного контейнера"
  value       = docker_container.nginx.id
}
```

`terraform.tfvars` (шаг 6.4):

```hcl
container_name = "tutorial-tfvars"
external_port  = 8081
```

### 3.2. Конфигурация CLI и обёртка запуска

Из-за региональной блокировки `releases.hashicorp.com` и `registry.terraform.io`
Terraform запускается из официального Docker-образа, а провайдер подключается
из локального файлового зеркала.

`terraform.tfrc`:

```hcl
provider_installation {
  filesystem_mirror {
    path    = "/workspace/.plugins"
    include = ["registry.terraform.io/kreuzwerker/docker"]
  }

  direct {
    exclude = ["registry.terraform.io/kreuzwerker/docker"]
  }
}
```

`scripts/tf.sh` (сокращённо):

```bash
docker run --rm -i \
  -v //var/run/docker.sock:/var/run/docker.sock \
  -v "${WINPATH}:/workspace" \
  -w "/workspace/${WORKDIR}" \
  -e TF_CLI_CONFIG_FILE=/workspace/terraform.tfrc \
  "${ENVARGS[@]}" \
  hashicorp/terraform:1.9.8 "$@"
```

`ENVARGS` формируется из переменных `TF_VAR_*` и `TF_LOG`, которые нужно явно пробросить
внутрь контейнера — `docker run` не наследует окружение хоста.

### 3.3. Снимки конфигурации по шагам

Каталог `task1/tutorials/` содержит состояние конфигурации после каждого руководства:
`03-build`, `04-change`, `05-destroy`, `06-variables`, `07-outputs`.

### 3.4. Конфигурационные файлы Ansible (задание 2)

**Инвентарь** `task2/inventory/hosts.yml` — узлы кластера `kind` из лабораторной работы №4:

```yaml
all:
  children:
    k8s:
      children:
        control_plane:
          hosts:
            lab4-control-plane:
        workers:
          hosts:
            lab4-worker:
            lab4-worker2:
      vars:
        ansible_connection: community.docker.docker
        ansible_host: "{{ inventory_hostname }}"
        ansible_user: root
        ansible_python_interpreter: /usr/bin/python3
        clear_proxy:
          http_proxy: ""
          https_proxy: ""
          HTTP_PROXY: ""
          HTTPS_PROXY: ""
```

Вложенные группы (`k8s → control_plane / workers`) повторяют пример из статьи
*How To Set Up Ansible Inventories*. Так как узлы kind — контейнеры без SSH, подключение
выполняется плагином `community.docker.docker` через `docker exec`.

**`task2/ansible.cfg`**:

```ini
[defaults]
inventory = inventory/hosts.yml
host_key_checking = False
interpreter_python = /usr/bin/python3
stdout_callback = default
```

**Основной playbook** `task2/playbooks/01-webserver.yml` (пример из *How To Write
Ansible Playbooks*: установить пакет, разложить конфигурацию по шаблону, перезапустить
службу обработчиком):

```yaml
- name: Веб-сервер на узлах кластера
  hosts: k8s
  gather_facts: true
  environment: "{{ clear_proxy }}"
  tasks:
    - name: Установить пакет nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: Разложить главную страницу из шаблона Jinja2
      ansible.builtin.template:
        src: ../templates/index.html.j2
        dest: /var/www/html/index.html
        mode: "0644"
      notify: перезагрузить nginx

    - name: Запустить nginx (если ещё не запущен)
      ansible.builtin.command: nginx
      args:
        creates: /run/nginx.pid

    - name: Проверить, что страница отдаётся по HTTP
      ansible.builtin.uri:
        url: http://127.0.0.1/
        return_content: true
        status_code: 200
      register: page

    - name: Показать заголовок страницы
      ansible.builtin.debug:
        msg: "{{ page.content | regex_search('<title>(.*?)</title>', '\\1') | first }}"

  handlers:
    - name: перезагрузить nginx
      ansible.builtin.command: nginx -s reload
```

**Шаблон** `task2/templates/index.html.j2` подставляет в страницу имя узла, его группы,
ОС, ядро и версию Python (данные `gather_facts`).

Остальные playbook: `00-bootstrap.yml` (установка python3 модулем `raw` и настройка
`apt` без недоступного прокси), `02-facts.yml` (вывод фактов об узлах),
`03-official-example.yml` («My first play» из документации *Creating a playbook*:
`ping` + `debug`). Управляющий узел — образ `task2/Dockerfile` (`alpine/ansible` +
`docker-cli`), обёртки запуска — `task2/scripts/ansible.sh` / `ansible.ps1`,
сквозной прогон — `task2/scripts/demo.sh`.

## 4. Результаты выполнения

### 4.1. Окружение

| Компонент | Версия |
|---|---|
| Terraform CLI | v1.9.8 (linux_amd64) |
| Провайдер `kreuzwerker/docker` | v4.2.0 |
| Docker | 29.8.1 |
| Хост | Windows 11, Docker Desktop, Git Bash |

### 4.2. Сводка по семи руководствам

| № | Руководство | Результат | Файл с выводом |
|---|-------------|-----------|----------------|
| 1 | What is Infrastructure as Code | конспект теории, понятия IaC, провайдера, ресурса, состояния | `evidence/01-iac.md` |
| 2 | Install Terraform | `Terraform v1.9.8`, провайдер установлен, контейнер отвечает HTTP 200 | `evidence/02-install.txt` |
| 3 | Build infrastructure | `Plan: 2 to add`, `Apply complete! Resources: 2 added` | `evidence/03-build.txt` |
| 4 | Change infrastructure | `must be replaced`, `Plan: 1 to add, 1 to destroy` | `evidence/04-change.txt` |
| 5 | Destroy infrastructure | `Destroy complete! Resources: 2 destroyed` | `evidence/05-destroy.txt` |
| 6 | Define input variables | 4 способа задания значений проверены | `evidence/06-variables.txt` |
| 7 | Query data with outputs | `output`, `-json`, `-raw` | `evidence/07-outputs.txt` |

### 4.3. Создание инфраструктуры (шаг 3)

```console
$ bash scripts/tf.sh -w learn-terraform-docker-container validate
Success! The configuration is valid.

$ bash scripts/tf.sh -w learn-terraform-docker-container plan
Plan: 2 to add, 0 to change, 0 to destroy.

$ bash scripts/tf.sh -w learn-terraform-docker-container apply
docker_image.nginx: Creation complete after 3s [id=sha256:65645c7bb6a0...]
docker_container.nginx: Creation complete after 1s [id=87af507bda9a...]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

$ bash scripts/tf.sh -w learn-terraform-docker-container state list
docker_container.nginx
docker_image.nginx

$ curl -s http://localhost:8000/ | grep -o "<title>[^<]*</title>"
<title>Welcome to nginx!</title>
```

### 4.4. Изменение инфраструктуры (шаг 4)

Изменён внешний порт 8000 → 8080:

```console
$ bash scripts/tf.sh -w learn-terraform-docker-container plan
  # docker_container.nginx must be replaced
      ~ external = 8000 -> 8080 # forces replacement

Plan: 1 to add, 0 to change, 1 to destroy.

$ bash scripts/tf.sh -w learn-terraform-docker-container apply
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

$ docker ps --filter name=tutorial
tutorial   65645c7bb6a0   Up 2 seconds   0.0.0.0:8080->80/tcp
```

Вывод: Terraform определяет, что изменение опубликованного порта требует замены ресурса
(`-/+`), и выполняет её автоматически. Символы плана: `+` создание, `~` изменение на месте,
`-` удаление, `-/+` замена.

### 4.5. Удаление инфраструктуры (шаг 5)

```console
$ bash scripts/tf.sh -w learn-terraform-docker-container destroy
Destroy complete! Resources: 2 destroyed.

$ docker ps -a --filter name=tutorial
NAMES     STATUS
```

### 4.6. Переменные (шаг 6)

| Способ | Команда | Результат |
|---|---|---|
| Значения по умолчанию | `apply` | `tutorial`, порт 8000 |
| Флаги `-var` | `apply -var container_name=tutorial-var -var external_port=8082` | `tutorial-var`, порт 8082 |
| Переменные окружения | `TF_VAR_container_name=tutorial-env TF_VAR_external_port=8083 apply` | `tutorial-env`, порт 8083 |
| Файл `terraform.tfvars` | `apply` (файл подхватывается автоматически) | `tutorial-tfvars`, порт 8081 |

Приоритет источников (слабый → сильный): переменные окружения → `terraform.tfvars` →
`*.auto.tfvars` → `-var` / `-var-file`.

### 4.7. Выходные значения (шаг 7)

```console
$ bash scripts/tf.sh -w learn-terraform-docker-container output
container_id   = "5278a666a1d15017485df7994db14eb759e76527a4188540fa0ebea973abf78e"
container_name = "tutorial-tfvars"

$ bash scripts/tf.sh -w learn-terraform-docker-container output -json
{ "container_id": {...}, "container_name": {...} }

$ bash scripts/tf.sh -w learn-terraform-docker-container output -raw container_id \
    | xargs docker inspect --format '{{.Name}} -> {{.State.Status}}'
/tutorial-tfvars -> running
```

Последняя команда показывает практическое применение outputs: значение из состояния
передаётся другому инструменту, и по нему проверяется фактическое состояние контейнера.

### 4.8. Особенности окружения

1. `releases.hashicorp.com` и `registry.terraform.io` возвращают из нашего региона
   «Content not available in your region», поэтому CLI запускается из Docker-образа,
   а провайдер берётся из релизов GitHub и подключается файловым зеркалом.
2. В примерах руководства используется образ `nginx:latest`; применён `nginx:1.27-alpine`,
   так как образы `nginx:latest` и `nginx:1.28` уже используются другими контейнерами хоста
   и `terraform destroy` не может их удалить.

### 4.9. Задание 2 (Ansible): окружение

| Компонент | Версия / значение |
|---|---|
| Ansible | `ansible [core 2.21.0]` (Python 3.14.10 в образе) |
| Образ управляющего узла | `lab5-ansible:1.0` (`alpine/ansible` + `docker-cli`) |
| Подключение | `community.docker.docker` (`docker exec`, без SSH) |
| Целевые узлы | 3 контейнера `kindest/node:v1.37.0` кластера `lab4`, Debian 13 trixie |
| Python на узлах | 3.13.5 (установлен playbook `00-bootstrap.yml`) |

Особенности стенда и их решение: (1) Ansible не работает на Windows как control node,
а WSL отключён — управляющий узел вынесен в контейнер с проброшенным
`/var/run/docker.sock`; (2) узлы kind — контейнеры без sshd — подключение через плагин
`community.docker.docker`; (3) минимальный образ kind не содержит python3 — первый
playbook ставит его модулем `raw`; (4) в узлах прописан недоступный прокси
`127.0.0.1:54031` — для `apt` он отключается файлом `/etc/apt/apt.conf.d/99-noproxy`
и очисткой переменных окружения. На логику задания это не влияет: инвентарь, ad-hoc
команды и playbook остаются штатными.

### 4.10. Задание 2: результаты тестирования

Все команды выполнены реально, вывод каждой сохранён в `task2/evidence/NN-*.txt`.
Сквозной прогон воспроизводится командой `bash task2/scripts/demo.sh` (9 шагов).

**Инвентарь и версия** (`evidence/01-inventory.txt`):

```console
$ ansible --version
ansible [core 2.21.0]

$ ansible-inventory --graph
@all:
  |--@ungrouped:
  |--@k8s:
  |  |--@control_plane:
  |  |  |--lab4-control-plane
  |  |--@workers:
  |  |  |--lab4-worker
  |  |  |--lab4-worker2
```

**Подключение к узлам кластера** (`evidence/02-adhoc-connect.txt`) — модуль `raw`
работает до появления python3 на узле:

```console
$ ansible k8s -m ansible.builtin.raw -a 'hostname; . /etc/os-release; echo $PRETTY_NAME'

lab4-control-plane | CHANGED | rc=0 >>
lab4-control-plane
Debian GNU/Linux 13 (trixie)

lab4-worker | CHANGED | rc=0 >>
lab4-worker
Debian GNU/Linux 13 (trixie)

lab4-worker2 | CHANGED | rc=0 >>
lab4-worker2
Debian GNU/Linux 13 (trixie)
```

**Подготовка узлов** (`evidence/03-bootstrap.txt`) — playbook `00-bootstrap.yml`:

```console
TASK [Установить python3 (apt, переменные прокси очищены)] ***
changed: [lab4-worker]
changed: [lab4-control-plane]
changed: [lab4-worker2]

TASK [Показать версию python3] ***
ok: [lab4-control-plane] => { "msg": "python3: Python 3.13.5 (было: absent)" }
...
PLAY RECAP ***
lab4-control-plane : ok=7  changed=2  unreachable=0  failed=0
lab4-worker        : ok=7  changed=2  unreachable=0  failed=0
lab4-worker2       : ok=7  changed=2  unreachable=0  failed=0
```

**Ad-hoc: ping и установка пакета `zsh`** (`evidence/04-adhoc-zsh.txt`) — п. 3 задания:

```console
$ ansible k8s -m ansible.builtin.ping
lab4-control-plane | SUCCESS => { "ping": "pong" }
lab4-worker        | SUCCESS => { "ping": "pong" }
lab4-worker2       | SUCCESS => { "ping": "pong" }

$ ansible k8s -m ansible.builtin.apt -a 'name=zsh state=present update_cache=yes'
lab4-worker2       | CHANGED => { ... "3 newly installed" ... }
lab4-control-plane | CHANGED => { ... }
lab4-worker        | CHANGED => { ... }

$ ansible k8s -m ansible.builtin.command -a 'zsh --version'
lab4-control-plane | CHANGED | rc=0 >>
zsh 5.9 (x86_64-debian-linux-gnu)
lab4-worker        | CHANGED | rc=0 >>
zsh 5.9 (x86_64-debian-linux-gnu)
lab4-worker2       | CHANGED | rc=0 >>
zsh 5.9 (x86_64-debian-linux-gnu)
```

**Playbook `02-facts.yml`** (`evidence/05-facts.txt`) — сбор фактов, `--limit` для
ограничения выборки:

```console
TASK [Основные характеристики узла] ***
ok: [lab4-control-plane] => {
    "msg": [
        "узел:        lab4-control-plane",
        "группы:      control_plane, k8s",
        "ОС:          Debian 13.6",
        "ядро:        6.18.54.1-microsoft-standard-WSL2",
        "CPU:         20 vCPU",
        "память:      7.7 ГиБ",
        "python:      3.13.5"
    ]
}

$ ansible k8s --limit lab4-worker -m ansible.builtin.command -a uptime
lab4-worker | CHANGED | rc=0 >>
 11:08:21 up  7:14,  0 users,  load average: 2.08, 1.31, 1.21
```

**Основной playbook `01-webserver.yml`** (`evidence/06-playbook.txt`) — п. 5 задания:

```console
$ ansible-playbook playbooks/01-webserver.yml --syntax-check
playbook: playbooks/01-webserver.yml

$ ansible-playbook playbooks/01-webserver.yml

TASK [Установить пакет nginx]                        changed: [все 3 узла]
TASK [Разложить главную страницу из шаблона Jinja2]  changed: [все 3 узла]
TASK [Запустить nginx (если ещё не запущен)]          changed: [все 3 узла]
TASK [Проверить, что страница отдаётся по HTTP]      ok: [все 3 узла]
TASK [Показать заголовок страницы] ***
ok: [lab4-control-plane] => { "msg": "lab4-control-plane" }
ok: [lab4-worker]        => { "msg": "lab4-worker" }
ok: [lab4-worker2]       => { "msg": "lab4-worker2" }

RUNNING HANDLER [перезагрузить nginx]                 changed: [все 3 узла]

PLAY RECAP ***
lab4-control-plane : ok=7  changed=4  unreachable=0  failed=0
lab4-worker        : ok=7  changed=4  unreachable=0  failed=0
lab4-worker2       : ok=7  changed=4  unreachable=0  failed=0
```

Обработчик вызван один раз в конце пьесы; модуль `uri` подтвердил HTTP 200;
`head -6 /var/www/html/index.html` на каждом узле показал свой `<title>lab4-…</title>`.

**Идемпотентность** (`evidence/07-idempotency.txt`) — повторный запуск того же playbook:

```console
$ ansible-playbook playbooks/01-webserver.yml
PLAY RECAP ***
lab4-control-plane : ok=6  changed=0  unreachable=0  failed=0
lab4-worker        : ok=6  changed=0  unreachable=0  failed=0
lab4-worker2       : ok=6  changed=0  unreachable=0  failed=0
```

Второй прогон не меняет состояние системы и не вызывает обработчик — ключевое
свойство декларативной модели Ansible.

**Пример из официального руководства** (`evidence/08-official-example.txt`) — п. 6
задания, «My first play» (`ping` + `debug`):

```console
$ ansible-playbook playbooks/03-official-example.yml
TASK [Ping my hosts] ***
ok: [все 3 узла]
TASK [Print message] ***
ok: [lab4-control-plane] => { "msg": "Hello world" }
ok: [lab4-worker]        => { "msg": "Hello world" }
ok: [lab4-worker2]       => { "msg": "Hello world" }
PLAY RECAP ***
lab4-control-plane : ok=3  changed=0  unreachable=0  failed=0
lab4-worker        : ok=3  changed=0  unreachable=0  failed=0
lab4-worker2       : ok=3  changed=0  unreachable=0  failed=0
```

**CLI-инструменты и очистка стенда** (`evidence/09-cli-and-cleanup.txt`) — п. 2 задания:
`--syntax-check` для всех четырёх playbook, `--list-hosts` (3 узла), `--list-tasks`
(5 задач), затем удаление тестовых `zsh`, `nginx` и страницы. Итоговая проверка
модулем `raw` на всех узлах: `python3=Python 3.13.5 zsh=absent nginx-bin=absent
index.html=absent` — стенд приведён в исходное состояние и готов к повторению.

Сводка соответствия пунктам задания 2:

| Пункт | Результат | Файл |
|---|---|---|
| 1. Инвентари, ad-hoc статьи | вложенные группы, `ansible-inventory --graph` | `hosts.yml`, `evidence/01` |
| 2. Using Ansible command line tools | `--version`, `--graph`, `--list-hosts`, `--list-tasks`, `--syntax-check`, `--limit` | `evidence/01`, `05`, `09` |
| 3. Подключение к ВМ кластера + пакет | `raw` к 3 узлам, `apt name=zsh`, `zsh --version` | `evidence/02`, `04` |
| 4–5. Playbook и демонстрация | nginx + Jinja2 + handler, `changed=4` → `changed=0` | `evidence/06`, `07` |
| 6. Примеры из руководства Ansible | «My first play» | `evidence/08` |
| 7. Публикация конфигурации | каталог `task2/` в репозитории | `task2/README.md` |

## 5. Ответы на контрольные вопросы

### 5.1. Ansible

**1. Для каких задач применяется Ansible?**
Управление конфигурацией серверов (установка пакетов, правка конфигов, запуск сервисов),
развёртывание приложений, оркестрация нескольких машин, выполнение разовых административных
задач, подготовка окружения (provisioning). Работает без агентов, по SSH.

**2. Какие способы управления серверами применяются в Ansible?**
Ad-hoc команды (модуль вызывается одной строкой), playbooks (файлы с описанием задач),
роли и collections (переиспользуемые наборы задач), а также подключение через
`ansible-playbook` в CI/CD. Транспорт — SSH для Linux, WinRM для Windows, локальное
или docker-подключение для контейнеров.

**3. Что входит в состав файла playbook?**
Список «пьес» (plays). Каждая содержит: `name`, `hosts` (группа целей), `become`
(повышение прав), `vars`, `tasks` (список задач: `name` + модуль с аргументами),
`handlers` (обработчики, вызываемые через `notify`), `roles`, `tags`.

**4. Что такое группы узлов (хостов) в Ansible?**
Именованные наборы хостов в инвентаре: `[web]`, `[db]`. Группы могут объединяться
через `[children]`, для группы задаются общие переменные в `group_vars/<группа>.yml`.
Команды и playbooks адресуются группе целиком.

**5. Как одной командой выполнить ping группы узлов?**
`ansible <группа> -m ping`, например `ansible web -m ping`. Это проверка доступности
и корректности подключения (модуль `ping` возвращает `pong`).

**6. Что такое роль Ansible?**
Способ организовать playbook в переиспользуемую структуру каталогов:
`tasks/`, `handlers/`, `templates/`, `files/`, `vars/`, `defaults/`, `meta/`.
Роль подключается блоком `roles:` или `include_role`, что позволяет применять
один и тот же набор задач к разным проектам.

**7. Что такое файл инвентаризации и как он используется?**
Файл со списком управляемых хостов и их групп (формат INI или YAML), при необходимости
с параметрами подключения (`ansible_host`, `ansible_user`, `ansible_port`).
Указывается в `ansible.cfg`, флагом `-i` или по умолчанию `/etc/ansible/hosts`;
по нему Ansible определяет, на каких машинах выполнять задачи.

**8. Что такое специальная (ad-hoc) команда Ansible?**
Одноразовая команда без playbook: `ansible <шаблон_хостов> -m <модуль> -a "<аргументы>"`.
Пример установки пакета: `ansible all -m apt -a "name=zsh state=present" -b`.

**9. Как перезапустить службу с помощью Ansible?**
Ad-hoc: `ansible <хост> -m service -a "name=nginx state=restarted" -b`.
В playbook — задача с модулем `service`/`systemd` и `state: restarted`, либо
`state: started` с `notify` на handler, который выполнит перезапуск только при изменении.

### 5.2. Terraform

**10. Что такое HashiCorp Terraform?**
Инструмент «инфраструктура как код»: описывает ресурсы разных провайдеров (облака,
виртуализация, Docker, DNS) в декларативных конфигурациях HCL и приводит реальную
инфраструктуру к описанному состоянию, храня состояние в `terraform.tfstate`.

**11. Что такое Infrastructure as Code (IaC)?**
Подход, при котором инфраструктура описывается текстовыми файлами в системе контроля
версий и применяется автоматически. Даёт воспроизводимость, ревью изменений, откат,
одинаковость окружений и документированность.

**12. Как установить Terraform?**
Скачать бинарник с `releases.hashicorp.com` и положить в `PATH`; использовать пакетный
менеджер (`brew install terraform`, `choco install terraform`, `apt` из репозитория
HashiCorp); запускать из официального Docker-образа `hashicorp/terraform`.
Проверка: `terraform version`.

**13. Что такое провайдер в Terraform?**
Плагин, реализующий API конкретной системы (AWS, Docker, Kubernetes). Указывается
в `required_providers` (`source`, `version`), настраивается блоком `provider`
(учётные данные, регион, хост API). Провайдеры скачиваются при `terraform init`.

**14. Объясните базовую структуру файла конфигурации Terraform.**
Файлы `.tf` в HCL состоят из блоков: `terraform` (версия Terraform, `required_providers`,
backend), `provider` (настройки провайдера), `resource` (управляемый объект:
тип + имя), `data` (чтение существующих объектов), `variable` (входные параметры),
`output` (выходные значения), `module` (подключение модулей), `locals`.
Значения переменных задаются в `terraform.tfvars`, `*.auto.tfvars`, флагами `-var`
или переменными окружения `TF_VAR_*`.

**15. Что такое файл состояния Terraform?**
`terraform.tfstate` — JSON-файл, в котором хранится соответствие ресурсов конфигурации
реальным объектам: их идентификаторы и все атрибуты, полученные от провайдера.
По нему Terraform понимает, что уже создано, и строит план. Для совместной работы
используется удалённый backend (S3, Terraform Cloud) с блокировкой состояния,
а `terraform.tfstate.backup` хранит предыдущую версию.

**16. Для чего нужна команда `terraform destroy`?**
Удаляет все ресурсы, описанные в конфигурации и присутствующие в состоянии: показывает
план удаления и после подтверждения уничтожает объекты и очищает состояние.
Применяется для разбора временных стендов, экономии ресурсов и чистой пересборки.

**17. Что такое состояние (state) в Terraform?**
Это снимок управляемой инфраструктуры и одновременно «источник истины» для планирования.
Terraform сравнивает три сущности: конфигурацию (что должно быть), состояние
(что, по его мнению, есть) и реальные объекты (что есть на самом деле).
Расхождение конфигурации и состояния даёт план изменений; расхождение состояния
и реальности исправляется `terraform refresh`/`apply`.

**18. Как определить зависимости в Terraform?**
Неявно — через ссылки на атрибуты других ресурсов:
`image = docker_image.nginx.image_id` создаёт зависимость `docker_container` → `docker_image`.
Явно — мета-аргументом `depends_on`, когда связи по атрибутам нет, но порядок важен.
Terraform строит граф зависимостей и выполняет операции параллельно там, где это безопасно.

## 6. Выводы

В ходе выполнения задания 1 освоен полный цикл работы с Terraform: описана инфраструктура
(образ и контейнер nginx) в декларативной конфигурации, выполнены `init`, `fmt`, `validate`,
`plan`, `apply`; изучено поведение Terraform при изменении ресурса (замена контейнера
при смене опубликованного порта) и при удалении (`destroy`); параметризована конфигурация
переменными (четыре способа задания значений) и выведены результаты через `outputs`.

В ходе выполнения задания 2 освоена работа с Ansible: составлен YAML-инвентарь с
вложенными группами, продемонстрированы ad-hoc команды (`raw`, `ping`, `apt`, `command`),
установлен пакет `zsh` на все узлы кластера Kubernetes, написаны и выполнены четыре
playbook (подготовка узлов через `raw`, веб-сервер с `apt` + Jinja2-шаблоном +
обработчиком, сбор фактов, пример из официального руководства). Показана идемпотентность:
повторный запуск того же playbook даёт `changed=0`. Отработаны CLI-инструменты
(`--syntax-check`, `--list-hosts`, `--list-tasks`, `--limit`, `ansible-inventory --graph`).

Дополнительно решены две практические задачи окружения: при недоступности официального
реестра провайдеры Terraform подключаются локальным файловым зеркалом, а CLI запускается
из официального образа; при отсутствии Linux-управляющего узла и SSH на целевых машинах
Ansible запускается в контейнере, а подключение к узлам `kind` идёт через плагин
`community.docker.docker`. Сами конфигурации и команды при этом остаются штатными.

## 7. Соответствие требованиям задания

| Требование | Где выполнено |
|---|---|
| 7 руководств Terraform выполнены и продемонстрированы | `task1/README.md`, `task1/evidence/01…07` |
| Инвентарь, ad-hoc команды, CLI-инструменты Ansible | `task2/inventory/hosts.yml`, `task2/evidence/01`, `04`, `09` |
| Подключение к узлам кластера и установка пакета | `task2/evidence/02`, `04` |
| Playbook настроены и продемонстрированы (вкл. идемпотентность) | `task2/playbooks/`, `task2/evidence/06`, `07` |
| Примеры из официального руководства Ansible | `task2/playbooks/03-official-example.yml`, `task2/evidence/08` |
| Код конфигурационных файлов опубликован | `task1/learn-terraform-docker-container/`, `task1/tutorials/`, `task2/` |
| Результаты тестирования по каждой программе | `task1/evidence/`, `task2/evidence/` (01…09) |
| Отчёт в формате Markdown | этот файл |
| Ссылка на отчёт в README | `README.md`, раздел Usage |
| Ответы на контрольные вопросы (18) | раздел 5 настоящего отчёта |
| Pull Request в git-репозитории | <!-- ссылка на PR --> |
