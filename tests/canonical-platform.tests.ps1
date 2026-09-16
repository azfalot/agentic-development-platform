$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
foreach($required in @('README.md','LICENSE','VERSION','guardrails\baseline-v1.json','scripts\bootstrap.ps1','scripts\agenthub.ps1','scripts\test.ps1','docs\ARCHITECTURE.md','.github\workflows\ci.yml')){
  Assert (Test-Path -LiteralPath (Join-Path $root $required)) "Missing public alpha artifact: $required"
}
$scanRoots=@('README.md','DEPRECATION.md','GLOBAL_DEV_POLICY.md','compiled','evidence','scripts','skills','templates','tests','bdd') | ForEach-Object {Join-Path $root $_}
$privatePatterns=@('C:'+'\\Users\\','Ho'+'kaido','\.agents(?:-|\\|/|`|$)','Gem'+'ini','Anti'+'gravity','postgres:postgres')
$files=@($scanRoots | ForEach-Object {if(Test-Path $_ -PathType Leaf){Get-Item $_}else{Get-ChildItem $_ -Recurse -File}})
foreach($pattern in $privatePatterns){
  $match=$files | Select-String -Pattern $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
  Assert ($null -eq $match) "Private or unsupported reference found: $pattern"
}
$baseline=Get-Content -Raw (Join-Path $root 'guardrails\baseline-v1.json') | ConvertFrom-Json
Assert ($baseline.baseline_findings.Count -eq 0) 'Public guardrail baseline must be empty'
Write-Output 'Canonical public-platform tests passed.'
exit 0
