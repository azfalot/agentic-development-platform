<#
.SYNOPSIS
  Project Compliance Auditor for Personal Agentic Development Platform v1.
  Audits a specific repository and produces structured status per requirement.
.EXAMPLE
  .\audit-project.ps1 -ProjectPath "C:\Projects\my-project"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

if (-not (Test-Path $ProjectPath)) {
    Write-Error "El directorio especificado no existe: $ProjectPath"
    exit 1
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Project Compliance Audit: $(Split-Path $ProjectPath -Leaf)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "Ruta: $ProjectPath`n" -ForegroundColor DarkCyan

function Report-Check {
    param(
        [string]$Category,
        [string]$Status, # COMPLIANT | PARTIALLY_COMPLIANT | NON_COMPLIANT | NOT_APPLICABLE
        [string]$Details,
        [string]$Remediation = ""
    )
    
    $color = switch ($Status) {
        "COMPLIANT" { "Green" }
        "PARTIALLY_COMPLIANT" { "Yellow" }
        "NON_COMPLIANT" { "Red" }
        "NOT_APPLICABLE" { "DarkGray" }
    }
    
    Write-Host ("[" + $Status.PadRight(19) + "] ") -NoNewline -ForegroundColor $color
    Write-Host ("${Category}: ") -NoNewline -ForegroundColor White
    Write-Host $Details -ForegroundColor Gray
    if ($Remediation -and $Status -ne "COMPLIANT" -and $Status -ne "NOT_APPLICABLE") {
        Write-Host ("                      -> Remediation: " + $Remediation) -ForegroundColor DarkCyan
    }
}

# 1. Check AGENTS.md / BDD Pointer
$agentsMd = Join-Path $ProjectPath "AGENTS.md"
if (Test-Path $agentsMd) {
    Report-Check -Category "BDD Contract Pointer" -Status "COMPLIANT" -Details "AGENTS.md present in repository root."
} else {
    Report-Check -Category "BDD Contract Pointer" -Status "NON_COMPLIANT" -Details "No AGENTS.md found in repository root." -Remediation "Create AGENTS.md from templates/AGENTS.md."
}

# 2. Check Database / Docker Compose
$composeFiles = Get-ChildItem -Path $ProjectPath -Include "*docker-compose*.yml","*docker-compose*.yaml","*compose*.yml","*compose*.yaml" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "node_modules" }

if ($composeFiles.Count -eq 0) {
    Report-Check -Category "Database Infrastructure" -Status "NOT_APPLICABLE" -Details "No Docker Compose files detected in project."
} else {
    $hasPostgresService = $false
    $hasDevNetwork = $false
    foreach ($cf in $composeFiles) {
        $content = Get-Content -Raw $cf.FullName -ErrorAction SilentlyContinue
        if ($content -match "image:\s*postgres" -or $content -match "services:\s*\n\s*postgres:") {
            $hasPostgresService = $true
        }
        if ($content -match "dev-network" -and $content -match "external:\s*true") {
            $hasDevNetwork = $true
        }
    }
    
    if (-not $hasPostgresService -and $hasDevNetwork) {
        Report-Check -Category "Database Infrastructure" -Status "COMPLIANT" -Details "Uses shared-postgres via external dev-network. No duplicate postgres container."
    } elseif ($hasPostgresService) {
        Report-Check -Category "Database Infrastructure" -Status "PARTIALLY_COMPLIANT" -Details "Defines a dedicated PostgreSQL service in Docker Compose." -Remediation "Remove postgres service and connect app to shared-postgres on dev-network."
    } else {
        Report-Check -Category "Database Infrastructure" -Status "COMPLIANT" -Details "No duplicate PostgreSQL service declared."
    }
}

# 3. Check Git Repository & Branch
$gitDir = Join-Path $ProjectPath ".git"
if (Test-Path $gitDir) {
    $branch = (git -C $ProjectPath branch --show-current 2>$null)
    if ($branch -eq "main" -or $branch -eq "master") {
        Report-Check -Category "Git Working Branch" -Status "PARTIALLY_COMPLIANT" -Details "Working tree is currently on '$branch'." -Remediation "Create a dedicated feature/<issue>-<name> branch before modifying code."
    } else {
        Report-Check -Category "Git Working Branch" -Status "COMPLIANT" -Details "Active branch is '$branch' (feature/fix branch isolation)."
    }
} else {
    Report-Check -Category "Git Working Branch" -Status "NON_COMPLIANT" -Details "Directory is not a Git repository." -Remediation "Initialize git repository with git init."
}

# 4. Check CI Workflow
$ciWorkflows = Join-Path $ProjectPath ".github\workflows"
if (Test-Path $ciWorkflows) {
    Report-Check -Category "CI/CD Gates" -Status "COMPLIANT" -Details "GitHub Actions workflows present in .github/workflows/."
} else {
    Report-Check -Category "CI/CD Gates" -Status "PARTIALLY_COMPLIANT" -Details "No GitHub Actions workflows found." -Remediation "Add CI workflow for automated build, lint, and test validation."
}

# 5. Check Architecture Decision Records (ADRs)
$adrDir = Join-Path $ProjectPath "docs\adr"
if (Test-Path $adrDir) {
    Report-Check -Category "Architecture Documentation" -Status "COMPLIANT" -Details "ADR directory found at docs/adr/."
} else {
    Report-Check -Category "Architecture Documentation" -Status "PARTIALLY_COMPLIANT" -Details "No docs/adr/ directory found." -Remediation "Create docs/adr/ and record significant architectural decisions."
}

Write-Host "`n=== Auditoria Finalizada ===" -ForegroundColor Cyan
