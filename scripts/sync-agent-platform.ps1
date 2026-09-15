<#
.SYNOPSIS
  Personal Agentic Development Platform v1 — Sync Script
  Compiles all global policies, installs all skills, and synchronizes with Antigravity and OpenAI Codex.
#>

$platformRoot = "C:\Users\Hokaido\.agents"
$policiesDir = Join-Path $platformRoot "policies"
$skillsDir = Join-Path $platformRoot "skills"
$compiledDir = Join-Path $platformRoot "compiled"
$compiledFile = Join-Path $compiledDir "GLOBAL_POLICY.md"
$globalDevPolicyFile = Join-Path $platformRoot "GLOBAL_DEV_POLICY.md"

if (-not (Test-Path $compiledDir)) {
    New-Item -ItemType Directory -Path $compiledDir -Force | Out-Null
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Personal Agentic Development Platform v1 — Synchronizer" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# 1. Compilar Políticas Globales
Write-Host "`n1. Compilando politicas globales desde $policiesDir..." -ForegroundColor Cyan

$policyFiles = Get-ChildItem -Path $policiesDir -Filter "*.md" | Sort-Object Name
$compiledContent = "# PERSONAL AGENTIC DEVELOPMENT PLATFORM v1 — GLOBAL POLICIES`n`n"
$compiledContent += "> Compilado automaticamente desde C:\Users\Hokaido\.agents\policies. NO editar manualmente.`n`n"

foreach ($pf in $policyFiles) {
    Write-Host ("   + " + $pf.Name) -ForegroundColor DarkCyan
    $content = Get-Content -Raw $pf.FullName
    $compiledContent += "`n---`n`n" + $content + "`n"
}

[System.IO.File]::WriteAllText($compiledFile, $compiledContent, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($globalDevPolicyFile, $compiledContent, [System.Text.Encoding]::UTF8)
Write-Host "   -> Compilado exitosamente en: $compiledFile" -ForegroundColor Green

# 2. Sincronizar con Antigravity (~/.gemini)
Write-Host "`n2. Sincronizando con Antigravity (~/.gemini)..." -ForegroundColor Cyan

$geminiConfigDir = "C:\Users\Hokaido\.gemini\config"
$geminiRulesDir = Join-Path $geminiConfigDir "rules"
$geminiSkillsBase = Join-Path $geminiConfigDir "skills"

if (-not (Test-Path $geminiRulesDir)) {
    New-Item -ItemType Directory -Path $geminiRulesDir -Force | Out-Null
}
if (-not (Test-Path $geminiSkillsBase)) {
    New-Item -ItemType Directory -Path $geminiSkillsBase -Force | Out-Null
}

$geminiRuleFile = Join-Path $geminiRulesDir "global-platform-policies.md"
[System.IO.File]::WriteAllText($geminiRuleFile, $compiledContent, [System.Text.Encoding]::UTF8)
Write-Host "   -> Regla global montada en: $geminiRuleFile" -ForegroundColor Green

# Copiar todas las skills a ~/.gemini/config/skills/
$skillFolders = Get-ChildItem -Path $skillsDir -Directory
foreach ($sf in $skillFolders) {
    $targetSkillDir = Join-Path $geminiSkillsBase $sf.Name
    if (-not (Test-Path $targetSkillDir)) {
        New-Item -ItemType Directory -Path $targetSkillDir -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $sf.FullName "*") -Destination $targetSkillDir -Recurse -Force
    Write-Host ("   + Antigravity Skill: " + $sf.Name) -ForegroundColor DarkCyan
}

# 3. Sincronizar con OpenAI Codex (~/.codex)
Write-Host "`n3. Sincronizando con OpenAI Codex (~/.codex)..." -ForegroundColor Cyan

$codexDir = "C:\Users\Hokaido\.codex"
$codexConfigFile = Join-Path $codexDir "config.toml"
$codexSkillsBase = Join-Path $codexDir "skills"

if (-not (Test-Path $codexSkillsBase)) {
    New-Item -ItemType Directory -Path $codexSkillsBase -Force | Out-Null
}

foreach ($sf in $skillFolders) {
    $targetSkillDir = Join-Path $codexSkillsBase $sf.Name
    if (-not (Test-Path $targetSkillDir)) {
        New-Item -ItemType Directory -Path $targetSkillDir -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $sf.FullName "*") -Destination $targetSkillDir -Recurse -Force
    Write-Host ("   + Codex Skill: " + $sf.Name) -ForegroundColor DarkCyan
}

if (Test-Path $codexConfigFile) {
    $rawToml = Get-Content -Raw $codexConfigFile
    
    $instructionsSummary = @"
PERSONAL AGENTIC DEVELOPMENT PLATFORM v1:
- BDD: Follow Behaviour Domain Driver (BDD) contract. Transition states: AVAILABLE -> PLANNING -> IMPLEMENTING -> TESTING -> WAITING_CI -> REVIEWING -> DONE.
- SHARED POSTGRESQL: A single shared PostgreSQL server runs at localhost:5432 / shared-postgres:5432 (Docker external network 'dev-network'). NEVER create new postgres containers or compose services.
- GIT WORKFLOW: Never commit directly to main. Use feature/<issue>-<name> branches, atomic conventional commits, and PRs.
- TESTING: Never delete or weaken tests (no green-by-deletion). Bug fixes require automated regression tests.
- EVIDENCE: Machine-verifiable evidence (logs, SHAs, Playwright traces) required before completing tasks.
Full platform policies: C:/Users/Hokaido/.agents/GLOBAL_DEV_POLICY.md
"@
    
    $tomlBlock = "developer_instructions = '''`n" + $instructionsSummary + "'''"
    
    if ($rawToml -match "developer_instructions\s*=") {
        $pattern = "(?s)developer_instructions\s*=\s*(?:'''.*?'''|`"`"`".*?`"`"`"|`".*?`")"
        $rawToml = [regex]::Replace($rawToml, $pattern, $tomlBlock)
    } else {
        $rawToml = $tomlBlock + "`n`n" + $rawToml
    }
    
    [System.IO.File]::WriteAllText($codexConfigFile, $rawToml, [System.Text.Encoding]::UTF8)
    Write-Host "   -> Codex config.toml actualizado exitosamente." -ForegroundColor Green
}

Write-Host "`n=== Sincronizacion Global Completada Exitosamente ===" -ForegroundColor Green
