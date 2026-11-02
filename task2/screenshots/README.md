# Скриншоты к заданию 2

Задание требует «продемонстрировать подключение к виртуальным машинам … и установку
пакета», «продемонстрировать playbook» и «продемонстрировать результаты» примеров из
руководства. Полный вывод команд уже лежит в [`../evidence/`](../evidence/), скриншоты
нужны как визуальное подтверждение, что всё выполнялось на своём компьютере.

Файлы кладутся в этот каталог, имена — латиницей.

## Подготовка

1. Открыть **Windows PowerShell** (или Windows Terminal с профилем PowerShell),
   развернуть на весь экран (`Win + ↑`).
2. Перейти в каталог задания:

```powershell
cd D:\大四上\НИиСПО\LAB5\task2
```

3. Перед каждой командой очищать экран: `Clear-Host`.

Снимок делается так: `Win + Shift + S` → прямоугольная область → выделить **команду
вместе с её выводом** → нажать на уведомление → `Ctrl + S` → сохранить в этот каталог.

> В системе нет Git Bash в `PATH`, поэтому используется обёртка
> [`../scripts/ansible.ps1`](../scripts/ansible.ps1) вместо `ansible.sh`. Аргументы
> у них одинаковые.
>
> **Если PowerShell блокирует запуск скриптов** (`无法加载文件 … 因为在此系统上禁止运行脚本`,
> `PSSecurityException`, `UnauthorizedAccess`), разрешите локальные скрипты один раз —
> права администратора не нужны, настройка действует только для текущего пользователя:
>
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```
>
> На вопрос ответить `Y` (`Д`). Проверка: `Get-ExecutionPolicy -List` — в строке `CurrentUser`
> должно быть `RemoteSigned`. Либо запускать скрипт разово в обход политики:
> `powershell -ExecutionPolicy Bypass -File .\scripts\ansible.ps1 ansible k8s -m ansible.builtin.ping`.

### Предварительные условия (один раз)

```powershell
# 1. кластер kind из лабораторной работы №4 запущен (три контейнера)
docker ps --filter name=lab4

# 2. образ управляющего узла собран
docker build -t lab5-ansible:1.0 .

# 3. узлы подготовлены (python3 + настройка apt) — иначе модули не работают
.\scripts\ansible.ps1 ansible-playbook playbooks/00-bootstrap.yml
```

> **Пути к playbook — только через `/`, не через `\`.** Аргументы после имени
> команды передаются внутрь Linux-контейнера без изменений: PowerShell сам
> обратные косые черты не преобразует, а в Linux путь `playbooks\02-facts.yml`
> не существует — Ansible ответит `the playbook … could not be found`
> (типичная ошибка, встречалась на практике). Поэтому во всех командах ниже
> написано `playbooks/…`. Локальные пути вроде `.\scripts\ansible.ps1` это
> не касается — их разбирает сам PowerShell.

> Команды из таблицы ниже рассчитаны на **чистое состояние узлов**: `zsh` и `nginx`
> не установлены, тестовая страница отсутствует. Тогда `apt` и playbook покажут
> `CHANGED` / `changed=4`, как в [`../evidence/`](../evidence/). Если вы уже запускали
> [`../scripts/demo.sh`](../scripts/demo.sh), его последний шаг как раз приводит стенд
> в это состояние повторно. При необходимости сбросить вручную:
>
> ```powershell
> .\scripts\ansible.ps1 ansible k8s -m ansible.builtin.apt -a 'name=zsh,nginx state=absent'
> .\scripts\ansible.ps1 ansible k8s -m ansible.builtin.file -a 'path=/var/www/html/index.html state=absent'
> ```

## Обязательные снимки (4)

Порядок важен: снимок 2 устанавливает `zsh` (он нужен для кадра 4), снимок 3
устанавливает `nginx`. Не запускайте `demo.sh` между снимками — он очистит стенд.

### 1. `ansible-inventory.png` — инвентарь и версия

```powershell
.\scripts\ansible.ps1 ansible --version
.\scripts\ansible.ps1 ansible-inventory --graph
```

В кадре должны быть: `ansible [core 2.21.0]`, `config file = /work/ansible.cfg` и дерево

```
@all:
  |--@ungrouped:
  |--@k8s:
  |  |--@control_plane:
  |  |  |--lab4-control-plane
  |  |--@workers:
  |  |  |--lab4-worker
  |  |  |--lab4-worker2
```

### 2. `adhoc-ping-zsh.png` — подключение и установка пакета (п. 3 задания)

```powershell
.\scripts\ansible.ps1 ansible k8s -m ansible.builtin.ping
.\scripts\ansible.ps1 ansible k8s -m ansible.builtin.apt -a 'name=zsh state=present update_cache=yes'
.\scripts\ansible.ps1 ansible k8s -m ansible.builtin.command -a 'zsh --version'
```

Ключевые строки: три `"ping": "pong"`, три `CHANGED` у `apt` и три строки
`zsh 5.9 (x86_64-debian-linux-gnu)`. Это и есть доказательство подключения ко всем
узлам кластера и установки пакета одной ad-hoc командой.

> В PowerShell аргумент модуля берите **в одиночные кавычки**: `-a 'name=zsh state=present …'`.
> Без кавычек пробел разобьёт строку на несколько аргументов и `apt` получит неверные
> параметры.

### 3. `playbook-webserver.png` — основной playbook (п. 5 задания)

```powershell
.\scripts\ansible.ps1 ansible-playbook playbooks/01-webserver.yml
```

В кадре обязательно должны попасть:

```
TASK [Установить пакет nginx]                     changed: [...]
TASK [Разложить главную страницу из шаблона Jinja2] changed: [...]
RUNNING HANDLER [перезагрузить nginx]
PLAY RECAP ***
lab4-control-plane : ok=7   changed=4   ... failed=0
lab4-worker        : ok=7   changed=4   ... failed=0
lab4-worker2       : ok=7   changed=4   ... failed=0
```

Полезно добавить в тот же кадр проверку страницы:

```powershell
.\scripts\ansible.ps1 ansible k8s -m ansible.builtin.command -a 'head -6 /var/www/html/index.html'
```

должны быть видны три разных `<title>lab4-…</title>` — страница собрана из Jinja2-шаблона
с данными каждого узла.

### 4. `facts.png` — сбор фактов об узлах

```powershell
.\scripts\ansible.ps1 ansible-playbook playbooks/02-facts.yml
```

Ключевые строки: блок `Основные характеристики узла` с `ОС: Debian 13.6`, `CPU: 20 vCPU`,
`память: 7.7 ГиБ`, `python: 3.13.5` и `msg: "zsh 5.9 …"` (пакет из снимка 2).

## Необязательный, но полезный (1)

### 5. `official-example.png` — пример из официального руководства (п. 6 задания)

```powershell
.\scripts\ansible.ps1 ansible-playbook playbooks/03-official-example.yml
```

В кадре — `TASK [Ping my hosts]`, `TASK [Print message]` и три `"msg": "Hello world"`.

Дополнительно можно снять CLI-инструменты (п. 2 задания) в отдельный кадр
`cli-tools.png`:

```powershell
.\scripts\ansible.ps1 ansible-playbook playbooks/01-webserver.yml --syntax-check
.\scripts\ansible.ps1 ansible-playbook playbooks/01-webserver.yml --list-hosts
.\scripts\ansible.ps1 ansible-playbook playbooks/01-webserver.yml --list-tasks
```

## Проверка

```powershell
Get-ChildItem .\screenshots\*.png | Select-Object Name, Length
```

Каждый файл — 40–300 КБ. Листинги тех же команд лежат в [`../evidence/`](../evidence/),
поэтому скриншоты — дополнение, а не единственное доказательство. После съёмки
передайте файлы для вставки в раздел «Скриншоты» файла [`../README.md`](../README.md).
