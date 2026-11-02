# Скриншоты к заданию 1

Задание требует «продемонстрировать выполнение каждого из руководств». Полный вывод команд
уже лежит в [`../evidence/`](../evidence/), скриншоты нужны как визуальное подтверждение,
что всё выполнялось на своём компьютере.

Файлы кладутся в этот каталог, имена — латиницей.

## Подготовка

1. Открыть **Windows PowerShell** (или Windows Terminal с профилем PowerShell),
   развернуть на весь экран (`Win + ↑`).
2. Перейти в каталог задания:

```powershell
cd D:\大四上\НИиСПО\LAB5\task1
```

3. Перед каждой командой очищать экран: `Clear-Host`.

Снимок делается так: `Win + Shift + S` → прямоугольная область → выделить **команду вместе
с её выводом** → нажать на уведомление → `Ctrl + S` → сохранить в этот каталог.

> В системе нет Git Bash в `PATH`, поэтому используется обёртка
> [`../scripts/tf.ps1`](../scripts/tf.ps1) вместо `tf.sh`. Аргументы у них одинаковые.
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
> должно быть `RemoteSigned`. Если политика задана групповой и менять её нельзя, запускать
> скрипт разово в обход: `powershell -ExecutionPolicy Bypass -File .\scripts\tf.ps1 version`.

## Обязательные снимки (4)

Порядок важен: снимки 1–4 идут по руководствам, `destroy` выполняется **последним**,
чтобы не удалять среду раньше времени.

> **Внимание.** В `apply` и `destroy` Terraform спрашивает подтверждение
> `Enter a value:` — нужно ввести `yes` и нажать Enter. Если просто нажать Enter,
> команда напишет `Apply cancelled.` и ничего не создаст, а все следующие снимки
> (`plan` покажет «will be created» вместо «must be replaced», `destroy` — «0 destroyed»)
> потеряют смысл. Поэтому во всех командах ниже стоит `-auto-approve`: подтверждение
> не запрашивается, а вывод сразу содержит `Apply complete!` / `Destroy complete!`.
>
> **Типичная ошибка (встречалась на практике).** Если запустить `apply` **без**
> `-auto-approve` и нажать Enter на `Enter a value:`, в кадре останется
> `Apply cancelled.`, `docker ps` будет пустым, `curl` ничего не выведет. Такой
> снимок непригоден. Признак правильного кадра: строка
> `Apply complete! Resources: 2 added, 0 changed, 0 destroyed.` и контейнер
> `tutorial   0.0.0.0:8000->80/tcp` в `docker ps`.

### 1. `terraform-version.png` — шаг 2, установка

```powershell
.\scripts\tf.ps1 version
docker images hashicorp/terraform
```

В кадре должно быть: `Terraform v1.9.8` и строка образа `hashicorp/terraform   1.9.8`.

### 2. `build-apply.png` — шаг 3, создание инфраструктуры

```powershell
.\scripts\tf.ps1 -w learn-terraform-docker-container apply -auto-approve -var container_name=tutorial -var external_port=8000
docker ps --filter name=tutorial
curl.exe -s http://localhost:8000/ | Select-String "<title>"
```

Ключевые строки:

```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
NAMES      PORTS
tutorial   0.0.0.0:8000->80/tcp
<title>Welcome to nginx!</title>
```

### 3. `change-plan.png` — шаг 4, изменение (самый содержательный кадр)

```powershell
.\scripts\tf.ps1 -w learn-terraform-docker-container plan -var container_name=tutorial -var external_port=8080
```

В кадре обязательно должно попасть:

```
  # docker_container.nginx must be replaced
      ~ external = 8000 -> 8080 # forces replacement
Plan: 1 to add, 0 to change, 1 to destroy.
```

Это доказательство, что Terraform умеет планировать изменения и понимает, что порт
нельзя поменять без пересоздания контейнера.

> `plan` ничего не создаёт, поэтому занятый порт 8080 здесь не мешает — команда только
> строит план. Файлы конфигурации при этом не меняются.

### 4. `destroy.png` — шаг 5, удаление (выполняется последним)

```powershell
.\scripts\tf.ps1 -w learn-terraform-docker-container destroy -auto-approve
docker ps -a --filter name=tutorial
.\scripts\tf.ps1 -w learn-terraform-docker-container state list
```

Ключевые строки: `Destroy complete! Resources: 2 destroyed.`, пустая таблица `docker ps -a`
и пустой вывод `state list` (ресурсов в состоянии нет).

## Необязательные, но полезные (2)

Делаются **до** снимка 4.

### 5. `outputs.png` — шаг 7

```powershell
.\scripts\tf.ps1 -w learn-terraform-docker-container output
```

В кадре — блок с `container_name = "tutorial"` и `container_id = "f61050d6…"`.

### 6. `variables.png` — шаг 6

```powershell
.\scripts\tf.ps1 -w learn-terraform-docker-container apply -auto-approve
docker ps --filter name=tutorial
```

Без флагов `-var` Terraform берёт значения из `terraform.tfvars`, поэтому в кадре должно быть
`+ name = "tutorial-tfvars"`, `+ external = 8081` и строка
`tutorial-tfvars   0.0.0.0:8081->80/tcp`. Это показывает источник значений переменных
(файл `terraform.tfvars`), в отличие от снимка 2, где значения заданы флагом `-var`.

> Порт 8081 должен быть свободен. После снимка контейнер всё равно удаляется командой из
> пункта 4.

## Проверка

```powershell
Get-ChildItem .\screenshots\*.png | Select-Object Name, Length
```

Каждый файл — 40–300 КБ. После съёмки в [`../README.md`](../README.md) можно сослаться
на снимки в разделе «Скриншоты».
