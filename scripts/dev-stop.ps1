[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$devCompose = Join-Path $repoRoot 'docker-compose.dev.yaml'

Push-Location $repoRoot

try {
    docker compose -f $devCompose down
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel parar o backend de desenvolvimento.'
    }

    Write-Host 'Backend de desenvolvimento parado.'
    Write-Host 'O volume com os dados de desenvolvimento foi preservado.'
} finally {
    Pop-Location
}
