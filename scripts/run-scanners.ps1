<#>
.SYNOPSIS
    Runs all security scanners against the mock application and generates SARIF/JSON reports.

.DESCRIPTION
    This script orchestrates the execution of multiple security scanning tools:
    - npq: Checks for malicious packages in package.json
    - semgrep: SAST with OWASP Top 10 ruleset
    - trivy fs: Filesystem scanning (vulns, misconfigs, secrets, licenses)
    - trivy image: Container image scanning
    - OWASP ZAP: DAST baseline scan

    All reports are saved to the artifacts/ directory in SARIF format (or native JSON for ZAP).

.NOTES
    Requires: Docker Desktop with WSL2 backend
    Run from the repository root: .\scripts\run-scanners.ps1
#>

param(
    [switch]$Clean,
    [switch]$SkipBuild,
    [string]$ArtifactsDir = "artifacts",
    [string]$MockAppDir = "mock-app",
    [int]$ZapPort = 4200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Log "Created directory: $Path"
    }
}

function Run-InDocker {
    param(
        [string]$Image,
        [string]$Command,
        [string[]]$Volumes,
        [string]$WorkDir = "/app",
        [string]$Name = ""
    )
    $volumeArgs = ($Volumes | ForEach-Object {
        # Fix Windows paths for Docker: C:\path -> /c/path
        $_ -replace '^([A-Z]):', '/$1' -replace '\\', '/'
    } | ForEach-Object { "-v $_" }) -join " "
    $nameArg = if ($Name) { "--name $Name" } else { "" }
    $cmd = "docker run --rm $nameArg -w $WorkDir $volumeArgs $Image $Command"
    Write-Log "Running: $cmd"
    Invoke-Expression $cmd
}

function Start-ZapTarget {
    param([string]$MockAppDir, [int]$Port)
    Write-Log "Building and starting Angular app for ZAP scan on port $Port..."
    $imageName = "mock-app:zap-target"
    docker build -t $imageName $MockAppDir
    $containerId = docker run -d -p "$Port:80" --name "mock-app-zap" $imageName
    Write-Log "Started container $containerId on port $Port"
    Start-Sleep -Seconds 5
    return $containerId
}

function Stop-ZapTarget {
    param([string]$ContainerId)
    if ($ContainerId) {
        Write-Log "Stopping ZAP target container..."
        docker stop $ContainerId | Out-Null
        docker rm $ContainerId | Out-Null
    }
}

# Main execution
$repoRoot = Get-Location
$artifactsPath = Join-Path $repoRoot $ArtifactsDir
$mockAppPath = Join-Path $repoRoot $MockAppDir

# Convert Windows paths to Docker-compatible format
function To-DockerPath {
    param([string]$Path)
    $Path -replace '^([A-Z]):', '/$1' -replace '\\', '/'
}

$dockerMockAppPath = To-DockerPath $mockAppPath
$dockerArtifactsPath = To-DockerPath $artifactsPath

if ($Clean) {
    Write-Log "Cleaning artifacts directory..."
    if (Test-Path $artifactsPath) {
        Remove-Item -Recurse -Force $artifactsPath
    }
    docker image prune -f | Out-Null
    Write-Log "Clean complete."
    exit 0
}

Ensure-Directory $artifactsPath

Write-Log "=========================================="
Write-Log "Starting Security Scanner Orchestration"
Write-Log "=========================================="

# 1. npq - Malicious package check
Write-Log ""
Write-Log "===== 1/5: npq (Malicious Package Check) ====="
try {
    Run-InDocker `
        -Image "node:20-alpine" `
        -Command "sh -c 'cd /app && npx -y npq --format=sarif > /out/npq.sarif'" `
        -Volumes @("${dockerMockAppPath}:/app", "${dockerArtifactsPath}:/out") `
        -Name "npq-scanner"
    Write-Log "npq scan completed. Report: $artifactsPath\npq.sarif"
} catch {
    Write-Log "npq scan failed: $_" "ERROR"
}

# 2. semgrep - SAST with OWASP Top 10
Write-Log ""
Write-Log "===== 2/5: semgrep (SAST - OWASP Top 10) ====="
try {
    Run-InDocker `
        -Image "returntocorp/semgrep:latest" `
        -Command "semgrep scan --config=p/owasp-top-ten --sarif --output=/out/semgrep.sarif /src" `
        -Volumes @("${dockerMockAppPath}:/src", "${dockerArtifactsPath}:/out") `
        -WorkDir "/src" `
        -Name "semgrep-scanner"
    Write-Log "semgrep scan completed. Report: $artifactsPath\semgrep.sarif"
} catch {
    Write-Log "semgrep scan failed: $_" "ERROR"
}

# 3. trivy fs - Filesystem scanning
Write-Log ""
Write-Log "===== 3/5: trivy fs (Filesystem Scan) ====="
try {
    Run-InDocker `
        -Image "aquasec/trivy:latest" `
        -Command "fs --format sarif --output /out/trivy-fs.sarif --scanners vuln,misconfig,secret,license /scan" `
        -Volumes @("${dockerMockAppPath}:/scan", "${dockerArtifactsPath}:/out") `
        -Name "trivy-fs-scanner"
    Write-Log "trivy fs scan completed. Report: $artifactsPath\trivy-fs.sarif"
} catch {
    Write-Log "trivy fs scan failed: $_" "ERROR"
}

# 4. trivy image - Container scanning
if (-not $SkipBuild) {
    Write-Log ""
    Write-Log "===== 4/5: Building mock app container image ====="
    try {
        docker build -t mock-app:test $mockAppPath
        Write-Log "Container image built: mock-app:test"
    } catch {
        Write-Log "Container build failed: $_" "ERROR"
    }
}

Write-Log ""
Write-Log "===== 4/5: trivy image (Container Scan) ====="
try {
    Run-InDocker `
        -Image "aquasec/trivy:latest" `
        -Command "image --format sarif --output /out/trivy-container.sarif mock-app:test" `
        -Volumes @("/var/run/docker.sock:/var/run/docker.sock", "${dockerArtifactsPath}:/out") `
        -Name "trivy-container-scanner"
    Write-Log "trivy container scan completed. Report: $artifactsPath\trivy-container.sarif"
} catch {
    Write-Log "trivy container scan failed: $_" "ERROR"
}

# 5. OWASP ZAP - DAST baseline scan
Write-Log ""
Write-Log "===== 5/5: OWASP ZAP (DAST Baseline Scan) ====="
$zapContainerId = $null
try {
    $zapContainerId = Start-ZapTarget -MockAppDir $mockAppPath -Port $ZapPort
    Write-Log "Waiting for app to be ready..."
    Start-Sleep -Seconds 10

    Run-InDocker `
        -Image "zaproxy/zap-stable:latest" `
        -Command "zap-baseline.py -t http://host.docker.internal:$ZapPort -r zap-report.html -J zap-report.json -x zap-report.xml" `
        -Volumes @("${dockerArtifactsPath}:/zap/wrk:rw") `
        -WorkDir "/zap/wrk" `
        -Name "zap-scanner"

    Write-Log "ZAP scan completed. Reports: $artifactsPath\zap-report.*"
} catch {
    Write-Log "ZAP scan failed: $_" "ERROR"
} finally {
    Stop-ZapTarget -ContainerId $zapContainerId
}

# Summary
Write-Log ""
Write-Log "=========================================="
Write-Log "Scanner Orchestration Complete"
Write-Log "=========================================="
Write-Log "Reports generated in: $artifactsPath"
Get-ChildItem $artifactsPath | ForEach-Object {
    Write-Log "  - $($_.Name) ($([math]::Round($_.Length / 1KB, 2)) KB)"
}

Write-Log ""
Write-Log "Next steps:"
Write-Log "  1. Start DefectDojo: docker compose -f infra/docker-compose.defectdojo.yml up -d"
Write-Log "  2. Import reports: python scripts/import-to-defectdojo.py"
Write-Log "  3. View findings in DefectDojo UI at http://localhost:8080"