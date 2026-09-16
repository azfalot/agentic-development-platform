function Get-GlobalGuardrailFindings {
  param([string]$TargetDirectory=(Join-Path $env:USERPROFILE 'Documents'))
  $findings=@()
  $composeFiles=Get-ChildItem -Path $TargetDirectory -Recurse -Depth 4 -Include '*docker-compose*.yml','*docker-compose*.yaml','*compose*.yml','*compose*.yaml' -ErrorAction SilentlyContinue | Where-Object {$_.FullName -notmatch 'node_modules' -and $_.FullName -notmatch '\.codex' -and $_.FullName -notmatch 'serene-fermi'}
  foreach($file in $composeFiles){
    $content=Get-Content -Raw $file.FullName -ErrorAction SilentlyContinue
    if($content -match 'image:\s*postgres' -or $content -match 'services:\s*\n\s*postgres:'){
      $relative=[IO.Path]::GetRelativePath($TargetDirectory,$file.FullName).Replace('\','/')
      $findings += [pscustomobject]@{rule='DUPLICATE_POSTGRES_SERVICE';repository=($relative -split '/')[0];path=$relative}
    }
  }
  @($findings)
}
Export-ModuleMember -Function Get-GlobalGuardrailFindings
