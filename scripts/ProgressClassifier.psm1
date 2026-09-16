function ConvertTo-AgentHubRelativePath {
  param([string]$Path)
  $Path.Replace('\','/').TrimStart('/')
}

function Test-AgentHubContractPath {
  param([string]$Path,$Contract)
  $normalized=ConvertTo-AgentHubRelativePath $Path
  if($Contract.scope.forbidden | Where-Object {$normalized -like $_}){return $false}
  [bool]($Contract.scope.allowed | Where-Object {$normalized -like $_})
}

function Get-AgentHubPathKind {
  param([string]$Path)
  $normalized=ConvertTo-AgentHubRelativePath $Path
  $name=[IO.Path]::GetFileName($normalized)
  if($normalized -match '(^|/)(tests?|__tests__|test)(/|$)' -or $name -match '(?i)(\.|-)(test|tests|spec)(\.|$)'){return 'test'}
  if($normalized -match '(?i)(^|/)(docs?|documentation)(/|$)' -or $name -match '(?i)^(readme|changelog|contributing|security|license)(\.|$)' -or $name -match '(?i)\.(md|mdx|rst|adoc|txt)$'){return 'documentation'}
  'implementation'
}

function Get-AgentHubChangeClassification {
  param([string[]]$ChangedFiles,$Contract)
  $changed=@($ChangedFiles | ForEach-Object {ConvertTo-AgentHubRelativePath $_} | Where-Object {$_})
  $invalid=@($changed | Where-Object {-not(Test-AgentHubContractPath $_ $Contract)})
  $scoped=@($changed | Where-Object {Test-AgentHubContractPath $_ $Contract})
  $tests=@($scoped | Where-Object {(Get-AgentHubPathKind $_) -eq 'test'})
  $documentation=@($scoped | Where-Object {(Get-AgentHubPathKind $_) -eq 'documentation'})
  $implementation=@($scoped | Where-Object {(Get-AgentHubPathKind $_) -eq 'implementation'})
  [pscustomobject]@{
    changed_files=$changed
    implementation_files=$implementation
    test_files=$tests
    documentation_files=$documentation
    invalid_files=$invalid
    source_change_detected=[bool]$implementation.Count
    test_change_detected=[bool]$tests.Count
    documentation_change_detected=[bool]$documentation.Count
    scope_valid=($invalid.Count -eq 0)
    progress_detected=([bool]$implementation.Count -and [bool]$tests.Count)
  }
}

Export-ModuleMember -Function Get-AgentHubChangeClassification,Get-AgentHubPathKind,Test-AgentHubContractPath
