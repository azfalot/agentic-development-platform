<# .SYNOPSIS Compiles repository policies into the selected platform home. #>
param([string]$PlatformHome = $(if($env:AGENT_PLATFORM_HOME){$env:AGENT_PLATFORM_HOME}else{Join-Path $HOME '.agent-platform'}))
$platformRoot = $PlatformHome
$policiesDir = Join-Path $platformRoot "policies"
$skillsDir = Join-Path $platformRoot "skills"
$compiledDir = Join-Path $platformRoot "compiled"
$compiledFile = Join-Path $compiledDir "GLOBAL_POLICY.md"
$globalDevPolicyFile = Join-Path $platformRoot "GLOBAL_DEV_POLICY.md"

if (-not (Test-Path $compiledDir)) {
    New-Item -ItemType Directory -Path $compiledDir -Force | Out-Null
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Agentic Development Platform — Policy compiler" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# 1. Compilar Políticas Globales
Write-Host "`n1. Compilando politicas globales desde $policiesDir..." -ForegroundColor Cyan

$policyFiles = Get-ChildItem -Path $policiesDir -Filter "*.md" | Sort-Object Name
$compiledContent = "# AGENTIC DEVELOPMENT PLATFORM — GLOBAL POLICIES`n`n"
$compiledContent += "> Compilado automaticamente desde policies/. NO editar manualmente.`n`n"

foreach ($pf in $policyFiles) {
    Write-Host ("   + " + $pf.Name) -ForegroundColor DarkCyan
    $content = Get-Content -Raw $pf.FullName
    $compiledContent += "`n---`n`n" + $content + "`n"
}

[System.IO.File]::WriteAllText($compiledFile, $compiledContent, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($globalDevPolicyFile, $compiledContent, [System.Text.Encoding]::UTF8)
Write-Host "   -> Compilado exitosamente en: $compiledFile" -ForegroundColor Green

Write-Host "`n=== Compilacion completada ===" -ForegroundColor Green
