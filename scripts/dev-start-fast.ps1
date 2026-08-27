[CmdletBinding()]
param(
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$devCompose = Join-Path $repoRoot 'docker-compose.dev.yaml'
$viteProcess = $null

function Get-CompatibleNode {
    $candidates = @()
    $pathNode = Get-Command node.exe -ErrorAction SilentlyContinue

    if ($pathNode) {
        $candidates += $pathNode.Source
    }

    $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $wingetPackages) {
        $candidates += Get-ChildItem -LiteralPath $wingetPackages -Directory -Filter 'OpenJS.NodeJS.22_*' -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter node.exe -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty FullName
            }
    }

    foreach ($nodeExe in ($candidates | Select-Object -Unique)) {
        try {
            $version = (& $nodeExe --version).Trim().TrimStart('v')
            $major = [int]($version.Split('.')[0])
            $npmExe = Join-Path (Split-Path -Parent $nodeExe) 'npm.cmd'

            if ($major -ge 18 -and $major -le 22 -and (Test-Path -LiteralPath $npmExe)) {
                return [pscustomobject]@{
                    Node = $nodeExe
                    Npm = $npmExe
                    Version = $version
                }
            }
        } catch {
            continue
        }
    }

    throw 'Node.js 18 a 22 nao foi encontrado. Instale o Node.js 22 antes de iniciar o frontend rapido.'
}

Push-Location $repoRoot

try {
    Write-Host '[10%] Verificando Docker...'
    docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop nao esta acessivel.'
    }

    Write-Host '[20%] Preparando a rede e o Ollama...'
    docker network inspect hub-ia_default 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        docker network create hub-ia_default | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Nao foi possivel criar a rede hub-ia_default.'
        }
    }

    docker network inspect hubdeia_default 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'A rede hubdeia_default nao existe. Inicie primeiro os containers da porta 3000.'
    }

    $ollamaStatus = docker container inspect ollama --format '{{.State.Status}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $ollamaStatus -ne 'running') {
        docker start ollama | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Nao foi possivel iniciar o container Ollama existente.'
        }
    }

    if ($LASTEXITCODE -eq 0) {
        $ollamaNetworks = docker container inspect ollama --format '{{json .NetworkSettings.Networks}}' | ConvertFrom-Json
        if ($ollamaNetworks.PSObject.Properties.Name -notcontains 'hub-ia_default') {
            docker network connect hub-ia_default ollama | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw 'Nao foi possivel conectar o Ollama a rede de desenvolvimento.'
            }
        }
    }

    $containerFrontendStatus = docker container inspect hub-ia-frontend-dev --format '{{.State.Status}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $containerFrontendStatus -eq 'running') {
        Write-Host '[30%] Liberando a porta 5173 do frontend em container...'
        docker stop hub-ia-frontend-dev | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Nao foi possivel parar o frontend em container.'
        }
    } else {
        Write-Host '[30%] A porta 5173 esta livre para o frontend nativo.'
    }

    Write-Host '[40%] Iniciando apenas o backend de desenvolvimento...'
    $env:WEBUI_DOCKER_TAG = 'v0.11.0'
    docker compose -f $devCompose up -d --no-build --pull missing backend
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel iniciar o backend de desenvolvimento.'
    }

    Write-Host '[50%] Localizando Node.js compativel...'
    $nodeRuntime = Get-CompatibleNode
    Write-Host "      Node.js $($nodeRuntime.Version)"

    $dependencyMarker = Join-Path $repoRoot 'node_modules\.cora-windows-package-lock.sha256'
    $lockHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot 'package-lock.json') -Algorithm SHA256).Hash
    $installedHash = if (Test-Path -LiteralPath $dependencyMarker) {
        (Get-Content -LiteralPath $dependencyMarker -Raw).Trim()
    } else {
        ''
    }
    $viteScript = Join-Path $repoRoot 'node_modules\vite\bin\vite.js'

    if ($installedHash -ne $lockHash -or -not (Test-Path -LiteralPath $viteScript)) {
        Write-Host '[60%] Instalando dependencias no Windows. Isso ocorre apenas no primeiro uso ou apos mudar o package-lock.json...'
        $env:CYPRESS_INSTALL_BINARY = '0'
        & $nodeRuntime.Npm ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) {
            throw 'A instalacao das dependencias do frontend falhou.'
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $dependencyMarker) -Force | Out-Null
        Set-Content -LiteralPath $dependencyMarker -Value $lockHash -NoNewline
    } else {
        Write-Host '[60%] Dependencias do frontend ja estao atualizadas.'
    }

    Write-Host '[70%] Aguardando o backend responder...'
    $backendDeadline = (Get-Date).AddMinutes(15)
    $backendReady = $false
    while ((Get-Date) -lt $backendDeadline) {
        try {
            $health = Invoke-RestMethod -Uri 'http://localhost:8080/health' -TimeoutSec 5
            $backendReady = $health.status -eq $true
        } catch {
            $backendReady = $false
        }

        if ($backendReady) {
            break
        }
        Start-Sleep -Seconds 5
    }

    if (-not $backendReady) {
        docker compose -f $devCompose logs --no-color --tail 100 backend
        throw 'O backend nao ficou pronto dentro de quinze minutos.'
    }

    Write-Host '[80%] Iniciando Vite diretamente no Windows...'
    $env:DEV_BACKEND_URL = 'http://localhost:8080'
    $viteProcess = Start-Process -FilePath $nodeRuntime.Node -ArgumentList @(
        'node_modules/vite/bin/vite.js',
        'dev',
        '--host',
        '0.0.0.0',
        '--port',
        '5173'
    ) -WorkingDirectory $repoRoot -NoNewWindow -PassThru

    $frontendDeadline = (Get-Date).AddMinutes(3)
    $frontendReady = $false
    while ((Get-Date) -lt $frontendDeadline -and -not $viteProcess.HasExited) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:5173' -TimeoutSec 5
            $frontendReady = $response.StatusCode -eq 200
        } catch {
            $frontendReady = $false
        }

        if ($frontendReady) {
            break
        }
        Start-Sleep -Seconds 2
    }

    if (-not $frontendReady) {
        throw 'O frontend nativo nao respondeu na porta 5173.'
    }

    Write-Host '[100%] Cora Dev esta pronta.'
    Write-Host 'Frontend rapido: http://localhost:5173'
    Write-Host 'Backend dev:     http://localhost:8080'
    Write-Host 'Mantenha esta janela aberta. Ctrl+C encerra somente o frontend rapido.'
    if (-not $NoBrowser) {
        Start-Process 'http://localhost:5173'
    }

    Wait-Process -Id $viteProcess.Id
} finally {
    if ($viteProcess -and -not $viteProcess.HasExited) {
        Stop-Process -Id $viteProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Pop-Location
}
