# OpenClaw CN Installer (Windows)
# Community: https://open-claw.org.cn/
# Usage 1 (run from repo root): .\scripts\install-cn.ps1
# Usage 2 (one-liner after publish): iwr -useb https://open-claw.org.cn/install-cn.ps1 | iex

param(
 [switch]$NoOnboard,
 [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$OpenClawCNGiteeRepo = "https://gitee.com/OpenClaw-CN/openclaw-cn.git"

Write-Host ""
Write-Host " OpenClaw CN - Install" -ForegroundColor Cyan
Write-Host " https://open-claw.org.cn/" -ForegroundColor Gray
Write-Host ""

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Error: PowerShell 5+ required" -ForegroundColor Red
    exit 1
}

$ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { "" }
$RepoDir = $null
if (-not [string]::IsNullOrWhiteSpace($ScriptDir) -and (Test-Path (Join-Path $ScriptDir "..\package.json"))) {
    $RepoDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
}
if (-not $RepoDir -or -not (Test-Path (Join-Path $RepoDir "pnpm-workspace.yaml"))) {
    if (-not [string]::IsNullOrWhiteSpace($OpenClawCNGiteeRepo)) {
        $RepoDir = Join-Path $env:USERPROFILE "openclaw-cn"
        if (-not (Test-Path (Join-Path $RepoDir "package.json"))) {
            Write-Host ">> Cloning OpenClaw CN from Gitee..." -ForegroundColor Yellow
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Host "Error: Git required. Install from https://git-scm.com/download/win" -ForegroundColor Red
                exit 1
            }
            git clone $OpenClawCNGiteeRepo $RepoDir
        }
    }
    if (-not $RepoDir -or -not (Test-Path (Join-Path $RepoDir "package.json")) -or -not (Test-Path (Join-Path $RepoDir "pnpm-workspace.yaml"))) {
        Write-Host "Error: OpenClaw repo root not found (need package.json and pnpm-workspace.yaml)" -ForegroundColor Red
        Write-Host "Run from repo root: .\scripts\install-cn.ps1" -ForegroundColor Yellow
        Write-Host "Or one-liner: iwr -useb https://open-claw.org.cn/install-cn.ps1 | iex" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "OK Repo root: $RepoDir" -ForegroundColor Green

if ($env:OPENCLAW_NO_ONBOARD -eq "1") { $NoOnboard = $true }
if ($env:OPENCLAW_DRY_RUN -eq "1") { $DryRun = $true }

function Check-Node {
    try {
        $nodeVersion = (node -v 2>$null)
        if ($nodeVersion) {
            $version = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
            if ($version -ge 22) {
                Write-Host "OK Node.js $nodeVersion found" -ForegroundColor Green
                return $true
            }
            Write-Host "! Node.js $nodeVersion found, v22+ required" -ForegroundColor Yellow
            return $false
        }
    } catch {}
    Write-Host "! Node.js not found" -ForegroundColor Yellow
    return $false
}

function Install-Node {
    Write-Host ">> Installing Node.js..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Using winget..." -ForegroundColor Gray
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ";" + [System.Environment]::GetEnvironmentVariable('Path','User')
        Write-Host "OK Node.js installed via winget" -ForegroundColor Green
        return
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  Using Chocolatey..." -ForegroundColor Gray
        choco install nodejs-lts -y
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ";" + [System.Environment]::GetEnvironmentVariable('Path','User')
        Write-Host "OK Node.js installed via Chocolatey" -ForegroundColor Green
        return
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "  Using Scoop..." -ForegroundColor Gray
        scoop install nodejs-lts
        Write-Host "OK Node.js installed via Scoop" -ForegroundColor Green
        return
    }
    Write-Host ""
    Write-Host "Error: No package manager (winget/choco/scoop). Install Node.js 22+ from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

function Invoke-Pnpm {
    param([string]$WorkDir, [string[]]$Arguments)
    $cmdExe = $env:ComSpec
    if (-not $cmdExe -or -not (Test-Path $cmdExe)) { $cmdExe = "cmd.exe" }
    $argList = @("/c", "pnpm") + $Arguments
    $p = Start-Process -FilePath $cmdExe -ArgumentList $argList -WorkingDirectory $WorkDir -Wait -NoNewWindow -PassThru
    return $p.ExitCode -eq 0
}

function Ensure-Pnpm {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        return
    }
    if (Get-Command corepack -ErrorAction SilentlyContinue) {
        try {
            corepack enable | Out-Null
            corepack prepare pnpm@latest --activate | Out-Null
            if (Get-Command pnpm -ErrorAction SilentlyContinue) {
                Write-Host "OK pnpm enabled via corepack" -ForegroundColor Green
                return
            }
        } catch {}
    }
    Write-Host ">> Installing pnpm..." -ForegroundColor Yellow
    npm install -g pnpm
    Write-Host "OK pnpm installed" -ForegroundColor Green
}

function Main {
    if ($DryRun) {
        Write-Host "OK Dry run - would use: $RepoDir" -ForegroundColor Green
        return
    }

    if (-not (Check-Node)) {
        Install-Node
        if (-not (Check-Node)) {
            Write-Host ""
            Write-Host "Error: Restart terminal after installing Node, then run this script again" -ForegroundColor Red
            exit 1
        }
    }

    Ensure-Pnpm

    # Prepend Git bin so pnpm's "bash scripts/bundle-a2ui.sh" uses Git Bash (not WSL); then Node so node is found
    $gitBin = $null
    $gitExe = (Get-Command git -ErrorAction SilentlyContinue).Source
    if ($gitExe) {
        $gitBin = [System.IO.Path]::GetDirectoryName($gitExe)
        if ($gitBin -and (Test-Path (Join-Path $gitBin "bash.exe"))) {
            $env:PATH = "$gitBin;$env:PATH"
        }
    }

    # Prepend Node to PATH and write path file for bundle-a2ui.sh (works with Git Bash, WSL, Cygwin)
    $nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
    $nodeDir = $null
    if ($nodeExe) {
        $nodeDir = [System.IO.Path]::GetDirectoryName($nodeExe)
        $env:PATH = "$nodeDir;$env:PATH"
        $nodeDirUnix = $nodeDir -replace '\\', '/'
        if ($nodeDirUnix -match '^([A-Za-z]):') {
            $nodeDirUnix = '/' + $Matches[1].ToLower() + $nodeDirUnix.Substring(2)
        }
        $pathFile = Join-Path $RepoDir ".openclaw-node-path"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($pathFile, $nodeDirUnix, $utf8NoBom)
    }

    Write-Host ">> pnpm install..." -ForegroundColor Yellow
    if (-not (Invoke-Pnpm -WorkDir $RepoDir -Arguments "install")) {
        Write-Host "Error: pnpm install failed" -ForegroundColor Red
        exit 1
    }
    Write-Host ">> pnpm ui:build..." -ForegroundColor Yellow
    if (-not (Invoke-Pnpm -WorkDir $RepoDir -Arguments "ui:build")) {
        Write-Host "! UI build failed, continuing (CLI may still work)" -ForegroundColor Yellow
    }
    Write-Host ">> pnpm build..." -ForegroundColor Yellow
    if (-not (Invoke-Pnpm -WorkDir $RepoDir -Arguments "build")) {
        Write-Host "Error: pnpm build failed" -ForegroundColor Red
        Write-Host "If you use WSL: open Git Bash or PowerShell in this repo and run: pnpm build" -ForegroundColor Gray
        Write-Host "Then run this installer again to install the wrapper." -ForegroundColor Gray
        exit 1
    }
    Write-Host "OK Build done" -ForegroundColor Green

    $nodePathFile = Join-Path $RepoDir ".openclaw-node-path"
    if (Test-Path $nodePathFile) { Remove-Item $nodePathFile -Force }

    $binDir = Join-Path $env:USERPROFILE ".local\bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    }
    $entryPath = Join-Path $RepoDir "dist\entry.js"
    if (-not (Test-Path $entryPath)) {
        Write-Host "Error: dist\entry.js not found. Run pnpm build first." -ForegroundColor Red
        exit 1
    }
    $cmdPath = Join-Path $binDir "openclaw.cmd"
    Set-Content -Path $cmdPath -Value "@echo off`r`nnode ""$entryPath"" %*`r`n" -NoNewline

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not ($userPath -split ";" | Where-Object { $_ -ieq $binDir })) {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$binDir", 'User')
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ";" + [System.Environment]::GetEnvironmentVariable('Path','User')
        Write-Host "! Added $binDir to PATH. Restart terminal if openclaw not found." -ForegroundColor Yellow
    }

    Write-Host "OK Wrapper installed: $cmdPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "OpenClaw CN installed." -ForegroundColor Green
    Write-Host "Community: https://open-claw.org.cn/" -ForegroundColor Cyan
    Write-Host "Repo: $RepoDir" -ForegroundColor Cyan
    Write-Host "Command: openclaw (restart terminal or refresh PATH)" -ForegroundColor Cyan
    Write-Host ""
    if (-not $NoOnboard) {
        Write-Host "Starting onboarding..." -ForegroundColor Cyan
        & $cmdPath onboard
    } else {
        Write-Host "Skipped onboarding. Run: openclaw onboard" -ForegroundColor Gray
    }
}

Main
