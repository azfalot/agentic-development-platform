param([string]$RepositoryRoot = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference='Stop'
$tests=Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'tests') -Filter '*.tests.ps1' | Sort-Object Name
foreach($test in $tests){
  Write-Host "==> $($test.Name)" -ForegroundColor Cyan
  & pwsh -NoProfile -File $test.FullName
  if($LASTEXITCODE -ne 0){throw "TEST_FAILED: $($test.Name)"}
}
Write-Output 'DETERMINISTIC_TEST_SUITE_PASSED'
