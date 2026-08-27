[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$devCompose = Join-Path $repoRoot 'docker-compose.dev.yaml'

Push-Location $repoRoot

try {
    Write-Host '[10%] Verificando Docker...'
    docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop nao esta acessivel.'
    }

    Write-Host '[20%] Verificando a rede compartilhada...'
    docker network inspect hub-ia_default 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        docker network create hub-ia_default | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Nao foi possivel criar a rede hub-ia_default.'
        }
    }

    $ollamaExists = docker container inspect ollama --format '{{.State.Status}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $ollamaExists -ne 'running') {
        Write-Host '[30%] Iniciando o container Ollama existente, sem pull...'
        docker start ollama | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Nao foi possivel iniciar o container Ollama existente.'
        }
    } elseif ($LASTEXITCODE -ne 0) {
        Write-Warning 'O container Ollama nao existe. O ambiente dev iniciara sem modelos locais.'
    }

    if ($ollamaExists) {
        $ollamaNetworks = docker container inspect ollama --format '{{json .NetworkSettings.Networks}}' | ConvertFrom-Json
        $ollamaConnected = $ollamaNetworks.PSObject.Properties.Name -contains 'hub-ia_default'
        if (-not $ollamaConnected) {
            docker network connect hub-ia_default ollama
            if ($LASTEXITCODE -ne 0) {
                throw 'Nao foi possivel conectar o Ollama a rede de desenvolvimento.'
            }
        }
    }

    Write-Host '[40%] Iniciando frontend em container e backend de desenvolvimento...'
    $env:WEBUI_DOCKER_TAG = 'v0.11.0'
    docker compose -f $devCompose --profile container-frontend up -d --no-build --pull missing
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel iniciar o ambiente de desenvolvimento.'
    }

    Write-Host '[60%] Aguardando o backend e o frontend ficarem saudaveis...'
    $deadline = (Get-Date).AddMinutes(15)
    $backendReady = $false
    $frontendReady = $false

    while ((Get-Date) -lt $deadline) {
        try {
            $backendHealth = Invoke-RestMethod -Uri 'http://localhost:8080/health' -TimeoutSec 5
            $backendReady = $backendHealth.status -eq $true
        } catch {
            $backendReady = $false
        }

        try {
            $frontendHealth = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:5173' -TimeoutSec 5
            $frontendReady = $frontendHealth.StatusCode -eq 200
        } catch {
            $frontendReady = $false
        }

        if ($backendReady -and $frontendReady) {
            break
        }

        Start-Sleep -Seconds 5
    }

    if (-not ($backendReady -and $frontendReady)) {
        docker compose -f $devCompose logs --no-color --tail 100 backend frontend
        throw 'O ambiente dev nao ficou pronto dentro de quinze minutos.'
    }

    Write-Host '[100%] Ambiente de desenvolvimento em containers pronto.'
    Write-Host 'Frontend: http://localhost:5173'
    Write-Host 'Backend:  http://localhost:8080'
    Write-Host 'Os containers continuarao ativos depois que este terminal for fechado.'
} finally {
    Pop-Location
}
