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

    Write-Host 'Frontend e backend de desenvolvimento parados.'
    Write-Host 'Os volumes com dados, dependencias e cache foram preservados.'
} finally {
    Pop-Location
}
