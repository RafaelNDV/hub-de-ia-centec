[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$devCompose = Join-Path $repoRoot 'docker-compose.dev.yaml'
$dependencyMarker = Join-Path $repoRoot 'node_modules\.hub-ia-package-lock.sha256'

Push-Location $repoRoot

try {
    Write-Host '[10%] Verificando Docker...'
    docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop nao esta acessivel.'
    }

    Write-Host '[20%] Garantindo que o Ollama e a rede compartilhada estejam ativos...'
    docker compose up -d --no-build ollama
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel iniciar o Ollama.'
    }

    Write-Host '[35%] Iniciando o backend de desenvolvimento...'
    $env:WEBUI_DOCKER_TAG = 'v0.11.0'
    docker compose -f $devCompose up -d --no-build
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel iniciar o backend de desenvolvimento.'
    }

    Write-Host '[50%] Aguardando o backend responder em http://localhost:8080/health ...'
    $deadline = (Get-Date).AddMinutes(4)
    $backendReady = $false

    while ((Get-Date) -lt $deadline) {
        try {
            $health = Invoke-RestMethod -Uri 'http://localhost:8080/health' -TimeoutSec 5
            if ($health.status -eq $true) {
                $backendReady = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 5
        }
    }

    if (-not $backendReady) {
        docker compose -f $devCompose logs --no-color --tail 100 backend
        throw 'O backend nao ficou pronto dentro de quatro minutos.'
    }

    Write-Host '[70%] Verificando dependencias do frontend...'
    $lockHash = (Get-FileHash (Join-Path $repoRoot 'package-lock.json') -Algorithm SHA256).Hash
    $installedHash = if (Test-Path -LiteralPath $dependencyMarker) {
        (Get-Content -Raw -LiteralPath $dependencyMarker).Trim()
    } else {
        ''
    }

    if ($installedHash -ne $lockHash) {
        Write-Host 'Instalando dependencias do frontend. Esta etapa demora mais na primeira vez...'
        npm ci
        if ($LASTEXITCODE -ne 0) {
            throw 'A instalacao das dependencias do frontend falhou.'
        }

        Set-Content -LiteralPath $dependencyMarker -Value $lockHash -NoNewline
    } else {
        Write-Host 'Dependencias do frontend ja estao atualizadas.'
    }

    Write-Host '[90%] Iniciando o frontend com atualizacao automatica...'
    Write-Host '[100%] Abra http://localhost:5173'
    Write-Host 'Mantenha este terminal aberto. Use Ctrl+C para parar o frontend.'
    # Os arquivos do Pyodide ja fazem parte do repositorio. Iniciar o Vite diretamente
    # evita baixar novamente esses pacotes a cada sessao de desenvolvimento.
    npx vite dev --host
} finally {
    Pop-Location
}
