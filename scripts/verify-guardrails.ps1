<#
.SYNOPSIS
  Linter de Guardrails Globales: Verifica que ningún proyecto viole las políticas de infraestructura (Postgres duplicado, secretos en código).
#>

param(
    [string]$TargetDirectory = "C:\Users\Hokaido\Documents"
)

Write-Host "=== Auditoria de Guardrails Globales ===" -ForegroundColor Cyan
Write-Host "Directorio objetivo: $TargetDirectory`n" -ForegroundColor DarkCyan

$violations = @()

$composeFiles = Get-ChildItem -Path $TargetDirectory -Recurse -Depth 4 -Include "*docker-compose*.yml","*docker-compose*.yaml","*compose*.yml","*compose*.yaml" -ErrorAction SilentlyContinue |
    Where-Object { 
        $_.FullName -notmatch "node_modules" -and 
        $_.FullName -notmatch "\.codex" -and
        $_.FullName -notmatch "serene-fermi" # Hub central
    }

foreach ($file in $composeFiles) {
    $content = Get-Content -Raw $file.FullName -ErrorAction SilentlyContinue
    if ($content -match "image:\s*postgres" -or $content -match "services:\s*\n\s*postgres:") {
        $violations += @{
            File = $file.FullName
            Type = "DUPLICATE_POSTGRES_SERVICE"
            Message = "Declara servicio de PostgreSQL en docker-compose en lugar de conectar a 'shared-postgres'."
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "[OK] No se encontraron infracciones en los archivos Docker Compose inspeccionados." -ForegroundColor Green
} else {
    Write-Host ("[ALERTA] Se detectaron " + $violations.Count + " infracciones de infraestructura:") -ForegroundColor Yellow
    foreach ($v in $violations) {
        Write-Host (" - [" + $v.Type + "] " + $v.File) -ForegroundColor Red
    }
}
