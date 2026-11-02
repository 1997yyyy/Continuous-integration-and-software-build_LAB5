<#
.SYNOPSIS
    Обёртка над Terraform CLI для Windows PowerShell: запускает hashicorp/terraform в Docker.

.DESCRIPTION
    Аналог scripts/tf.sh. В системе нет Git Bash, поэтому используется PowerShell.
    Каталог задания монтируется в /workspace, сокет Docker-демона — внутрь контейнера,
    поэтому Terraform управляет контейнерами хост-машины.
    Переменные окружения TF_VAR_* и TF_LOG пробрасываются в контейнер.

    Аргументы передаются в Terraform как есть, включая -var / -auto-approve / -no-color.

.EXAMPLE
    .\scripts\tf.ps1 version

.EXAMPLE
    .\scripts\tf.ps1 -w learn-terraform-docker-container plan

.EXAMPLE
    .\scripts\tf.ps1 -w learn-terraform-docker-container apply -var external_port=8000
#>

$all = @($args)

$workdir = '.'
if ($all.Count -ge 2 -and ($all[0] -eq '-w' -or $all[0] -eq '--workdir')) {
    $workdir = $all[1]
    if ($all.Count -gt 2) { $all = @($all[2..($all.Count - 1)]) } else { $all = @() }
}

if ($all.Count -eq 0) {
    Write-Host 'usage: scripts\tf.ps1 [-w <workdir>] <terraform args>' -ForegroundColor Yellow
    Write-Host 'example: scripts\tf.ps1 -w learn-terraform-docker-container plan' -ForegroundColor DarkGray
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot          # каталог task1
$mount = $root.Replace('\', '/')

$auto = if ($env:TF_IN_AUTOMATION) { $env:TF_IN_AUTOMATION } else { '1' }

$dockerArgs = @(
    'run', '--rm', '-i',
    '-v', '/var/run/docker.sock:/var/run/docker.sock',
    '-v', "${mount}:/workspace",
    '-w', "/workspace/$workdir",
    '-e', 'TF_CLI_CONFIG_FILE=/workspace/terraform.tfrc',
    '-e', 'CHECKPOINT_DISABLE=1',
    '-e', "TF_IN_AUTOMATION=$auto"
)

# пробросить TF_VAR_* / TF_LOG в контейнер (docker run не наследует окружение хоста)
Get-ChildItem env: |
    Where-Object { $_.Name -match '^(TF_VAR_|TF_LOG)' } |
    ForEach-Object { $dockerArgs += @('-e', "$($_.Name)=$($_.Value)") }

$dockerArgs += 'hashicorp/terraform:1.9.8'
$dockerArgs += $all

& docker @dockerArgs
exit $LASTEXITCODE
