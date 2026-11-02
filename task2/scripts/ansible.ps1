# Обёртка над управляющим узлом Ansible для Windows PowerShell.
#
# Ansible не поддерживает Windows как управляющую машину, а WSL в этой системе
# отключён, поэтому ansible / ansible-playbook запускаются в контейнере
# lab5-ansible:1.0. Каталог задания монтируется в /work, сокет Docker — внутрь:
# плагин community.docker.docker выполняет команды в узлах кластера kind.
#
# Примеры:
#   .\scripts\ansible.ps1 ansible-inventory --graph
#   .\scripts\ansible.ps1 ansible k8s -m ansible.builtin.ping
#   .\scripts\ansible.ps1 ansible-playbook playbooks/01-webserver.yml

$all = @($args)

if ($all.Count -eq 0) {
    Write-Host 'usage: scripts\ansible.ps1 <ansible|ansible-playbook|ansible-inventory|...> [args]' -ForegroundColor Yellow
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot          # каталог task2
$mount = $root.Replace('\', '/')

$dockerArgs = @(
    'run', '--rm', '-i',
    '-v', '/var/run/docker.sock:/var/run/docker.sock',
    '-v', "${mount}:/work",
    '-w', '/work',
    '-e', 'ANSIBLE_CONFIG=/work/ansible.cfg',
    '-e', 'ANSIBLE_FORCE_COLOR=0',
    '-e', 'ANSIBLE_HOST_KEY_CHECKING=False',
    'lab5-ansible:1.0'
) + $all

& docker @dockerArgs
exit $LASTEXITCODE
