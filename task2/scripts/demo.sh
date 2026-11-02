#!/usr/bin/env bash
# Сквозной прогон задания 2: ad-hoc команды и playbooks на узлах кластера kind.
# Вывод каждой команды сохраняется в evidence/NN-*.txt — это и есть
# «результаты тестирования» для отчёта.
#
# ВАЖНО (идемпотентность): файлы evidence/ зафиксированы при первом прогоне на
# «чистых» узлах kind (без python3, zsh и nginx). При повторном запуске часть
# задач покажет ok/skipped вместо changed — это штатное поведение Ansible,
# а не ошибка. Стенд после шага 9 снова приведён в исходное состояние.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p evidence

run() {   # run <файл> <заголовок> <команда...>
  local out="$1"; shift
  local title="$1"; shift
  {
    echo "# $title"
    echo "\$ scripts/ansible.sh $*"
    echo
    bash scripts/ansible.sh "$@" 2>&1
    echo
  } >> "$out"
}

: > evidence/01-inventory.txt
: > evidence/02-adhoc-connect.txt
: > evidence/03-bootstrap.txt
: > evidence/04-adhoc-zsh.txt
: > evidence/05-facts.txt
: > evidence/06-playbook.txt
: > evidence/07-idempotency.txt
: > evidence/08-official-example.txt
: > evidence/09-cli-and-cleanup.txt

echo '[1/9] инвентарь'
run evidence/01-inventory.txt 'Версия Ansible и структура инвентаря' \
  ansible --version
run evidence/01-inventory.txt 'Граф инвентаря' \
  ansible-inventory --graph

echo '[2/9] ad-hoc: подключение к узлам (модуль raw)'
run evidence/02-adhoc-connect.txt 'Подключение к узлам кластера без Python на узле' \
  ansible k8s -m ansible.builtin.raw -a 'hostname; . /etc/os-release; echo $PRETTY_NAME'

echo '[3/9] подготовка узлов: python3 и apt'
run evidence/03-bootstrap.txt 'Playbook 00-bootstrap.yml' \
  ansible-playbook playbooks/00-bootstrap.yml

echo '[4/9] ad-hoc: установка пакета zsh'
run evidence/04-adhoc-zsh.txt 'Проверка связи модулем ping' \
  ansible k8s -m ansible.builtin.ping
run evidence/04-adhoc-zsh.txt 'Установка пакета zsh на все узлы' \
  ansible k8s -m ansible.builtin.apt -a 'name=zsh state=present update_cache=yes'
run evidence/04-adhoc-zsh.txt 'Проверка результата' \
  ansible k8s -m ansible.builtin.command -a 'zsh --version'

echo '[5/9] факты об узлах'
run evidence/05-facts.txt 'Playbook 02-facts.yml' \
  ansible-playbook playbooks/02-facts.yml
run evidence/05-facts.txt 'Ограничение выборки: --limit lab4-worker' \
  ansible k8s --limit lab4-worker -m ansible.builtin.command -a 'uptime'

echo '[6/9] playbook: nginx + шаблон + обработчик'
run evidence/06-playbook.txt 'Проверка синтаксиса' \
  ansible-playbook playbooks/01-webserver.yml --syntax-check
run evidence/06-playbook.txt 'Первый запуск' \
  ansible-playbook playbooks/01-webserver.yml
run evidence/06-playbook.txt 'Проверка содержимого страницы на узлах' \
  ansible k8s -m ansible.builtin.command -a 'head -6 /var/www/html/index.html'

echo '[7/9] повторный запуск (идемпотентность)'
run evidence/07-idempotency.txt 'Повторный запуск того же playbook' \
  ansible-playbook playbooks/01-webserver.yml

echo '[8/9] playbook из официального руководства'
run evidence/08-official-example.txt 'Playbook из официального руководства Ansible («Creating a playbook»)' \
  ansible-playbook playbooks/03-official-example.yml

echo '[9/9] инструменты CLI и очистка стенда'
for p in playbooks/*.yml; do
  run evidence/09-cli-and-cleanup.txt "Проверка синтаксиса: $p" \
    ansible-playbook "$p" --syntax-check
done
run evidence/09-cli-and-cleanup.txt 'Список узлов playbook (--list-hosts)' \
  ansible-playbook playbooks/01-webserver.yml --list-hosts
run evidence/09-cli-and-cleanup.txt 'Список задач playbook (--list-tasks)' \
  ansible-playbook playbooks/01-webserver.yml --list-tasks
run evidence/09-cli-and-cleanup.txt 'Очистка: удалить тестовые пакеты' \
  ansible k8s -m ansible.builtin.apt -a 'name=zsh,nginx state=absent'
run evidence/09-cli-and-cleanup.txt 'Очистка: удалить тестовую страницу' \
  ansible k8s -m ansible.builtin.file -a 'path=/var/www/html/index.html state=absent'
run evidence/09-cli-and-cleanup.txt 'Итоговая проверка состояния узлов' \
  ansible k8s -m ansible.builtin.raw -a 'printf "python3=%s " "$(/usr/bin/python3 --version 2>&1)"; printf "zsh=%s " "$(command -v zsh >/dev/null && echo present || echo absent)"; printf "nginx-bin=%s " "$(command -v nginx >/dev/null && echo present || echo absent)"; printf "index.html=%s\n" "$(test -f /var/www/html/index.html && echo present || echo absent)"'

echo
echo 'готово:'
wc -l evidence/*.txt
