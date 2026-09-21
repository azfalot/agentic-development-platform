# ProgressClassifier.psm1
# Task-contract progress and change classification engine for AgentHub

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ArtifactClassification.psm1') -Force

function ConvertTo-AgentHubRelativePath {
  param([string]$Path)
  ConvertTo-AgentHubCanonicalPath $Path
}

function Test-AgentHubContractPath {
  param([string]$Path, $Contract)
  $normalized = ConvertTo-AgentHubCanonicalPath $Path
  if ($null -ne $Contract -and $null -ne $Contract.scope -and $null -ne $Contract.scope.forbidden) {
    if ($Contract.scope.forbidden | Where-Object { $normalized -like (ConvertTo-AgentHubCanonicalPath $_) }) {
      return $false
    }
  }
  if ($null -ne $Contract -and $null -ne $Contract.scope -and $null -ne $Contract.scope.allowed) {
    return [bool]($Contract.scope.allowed | Where-Object { $normalized -like (ConvertTo-AgentHubCanonicalPath $_) })
  }
  return $false
}

function Get-AgentHubPathKind {
  param([string]$Path)
  $classification = (Get-AgentHubPathClassification -Path $Path).classification
  switch ($classification) {
    'TEST_CHANGE'          { return 'test' }
    'DOCUMENTATION_CHANGE' { return 'documentation' }
    default                { return 'implementation' }
  }
}

function Get-AgentHubChangeClassification {
  param(
    [string[]]$ChangedFiles,
    $Contract,
    [string]$RepositoryPath = '',
    $EnvironmentDiscovery = $null
  )
  $changed = @($ChangedFiles | ForEach-Object { ConvertTo-AgentHubCanonicalPath $_ } | Where-Object { $_ })

  $classifiedItems = @()
  $invalid = @()
  $scoped = @()
  $tests = @()
  $documentation = @()
  $implementation = @()
  $disposable = @()

  foreach ($file in $changed) {
    $item = Get-AgentHubArtifactClassification `
      -Path $file `
      -RepositoryPath $RepositoryPath `
      -Contract $Contract `
      -EnvironmentDiscovery $EnvironmentDiscovery

    $classifiedItems += $item

    if (-not $item.scope_relevant) {
      $disposable += $file
      continue
    }

    if ($item.scope_decision -eq 'SCOPE_VIOLATION') {
      $invalid += $file
    } else {
      $scoped += $file
      switch ($item.classification) {
        'TEST_CHANGE'          { $tests += $file }
        'DOCUMENTATION_CHANGE' { $documentation += $file }
        default                { $implementation += $file }
      }
    }
  }

  [pscustomobject]@{
    changed_files                 = $changed
    implementation_files          = $implementation
    product_files                 = $implementation
    test_files                    = $tests
    documentation_files           = $documentation
    disposable_files              = $disposable
    invalid_files                 = $invalid
    classified_items              = $classifiedItems
    source_change_detected        = [bool]$implementation.Count
    test_change_detected          = [bool]$tests.Count
    documentation_change_detected = [bool]$documentation.Count
    scope_valid                   = ($invalid.Count -eq 0)
    progress_detected             = ([bool]$implementation.Count -and [bool]$tests.Count)
  }
}

Export-ModuleMember -Function `
  ConvertTo-AgentHubRelativePath, `
  Test-AgentHubContractPath, `
  Get-AgentHubPathKind, `
  Get-AgentHubChangeClassification, `
  Get-AgentHubArtifactClassification, `
  Get-AgentHubPathClassification, `
  Get-AgentHubTrackedState, `
  Test-AgentHubArtifactScopeRelevance, `
  ConvertTo-AgentHubCanonicalPath
