# ArtifactClassification.psm1
# Deterministic Artifact Classification and Scope-Relevance Engine for AgentHub

$ErrorActionPreference = 'Stop'

function ConvertTo-AgentHubCanonicalPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  $clean = $Path.Replace('\', '/').Trim()
  while ($clean.StartsWith('./')) { $clean = $clean.Substring(2) }
  $clean.TrimStart('/')
}

function Get-AgentHubTrackedState {
  param(
    [string]$Path,
    [string]$RepositoryPath,
    [string]$ExplicitTrackedState = ''
  )
  if (-not [string]::IsNullOrWhiteSpace($ExplicitTrackedState)) {
    return $ExplicitTrackedState.ToUpperInvariant()
  }
  if ([string]::IsNullOrWhiteSpace($RepositoryPath) -or -not (Test-Path -LiteralPath (Join-Path $RepositoryPath '.git'))) {
    return 'UNTRACKED'
  }
  $normalized = ConvertTo-AgentHubCanonicalPath $Path
  if ([string]::IsNullOrWhiteSpace($normalized)) { return 'UNTRACKED' }

  # 1. Check if tracked by Git index / tree
  $null = git -C $RepositoryPath ls-files --error-unmatch -- $normalized 2>&1
  if ($LASTEXITCODE -eq 0) {
    return 'TRACKED'
  }

  # 2. Check if ignored by .gitignore
  $null = git -C $RepositoryPath check-ignore -q -- $normalized 2>&1
  if ($LASTEXITCODE -eq 0) {
    return 'IGNORED'
  }

  return 'UNTRACKED'
}

function Get-AgentHubPathClassification {
  param(
    [string]$Path,
    $EnvironmentDiscovery = $null
  )
  $normalized = ConvertTo-AgentHubCanonicalPath $Path
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    return @{
      classification = 'UNKNOWN'
      classification_source = 'default_fallback'
    }
  }

  $filename = [IO.Path]::GetFileName($normalized)

  # 1. AGENTHUB_EVIDENCE / RUNTIME_ARTIFACT
  if ($normalized -match '(?i)(^|/)(\.agenthub(/|$)|TASK_CONTRACT\.json$|\.agenthub-)') {
    return @{
      classification = 'AGENTHUB_EVIDENCE'
      classification_source = 'agenthub_runtime'
    }
  }

  # 2. TEST_ARTIFACT (Discovered test outputs, reports, and coverage)
  if ($normalized -match '(?i)(^|/)(playwright-report|test-results|coverage|\.nyc_output|allure-results|surefire-reports)(/|$)' -or
      $filename -match '(?i)\.(trx|coverage)$') {
    return @{
      classification = 'TEST_ARTIFACT'
      classification_source = 'well_known_test_output'
    }
  }

  # 3. DEPENDENCY_ARTIFACT (Discovered package manager caches, modules, stores)
  if ($normalized -match '(?i)(^|/)(node_modules|\.npm|\.npm-cache|\.pnpm-store|\.yarn/cache|\.yarn/unplugged|\.nuget/packages|\.nuget)(/|$)' -or
      $normalized -match '(?i)(^|/)vendor/(bundle|cache)(/|$)') {
    return @{
      classification = 'DEPENDENCY_ARTIFACT'
      classification_source = 'well_known_dependency'
    }
  }

  # 4. BUILD_ARTIFACT (Discovered compiler outputs, bundles, binaries, obj)
  if ($normalized -match '(?i)(^|/)(target|build|dist|out|bin|obj|\.parcel-cache|\.next|\.nuxt|\.turbo|\.cache)(/|$)' -or
      $filename -match '(?i)\.(dll|exe|class|o|obj|pyc|pyo|pyd|so|dylib|wasm|pdb)$') {
    return @{
      classification = 'BUILD_ARTIFACT'
      classification_source = 'well_known_build'
    }
  }

  # 5. TEST_CHANGE (Source code for tests, test suites, specs)
  if ($normalized -match '(?i)(^|/)(tests?|__tests__|specs?|qa)(/|$)' -or
      $filename -match '(?i)(\.|-|_)(test|tests|spec)\.[a-z0-9]+$' -or
      $filename -match '(?i)^test_[a-z0-9_]+\.[a-z0-9]+$' -or
      $filename -match '(?i)[a-z0-9_]+(test|tests)\.(cs|java|go|rs|py|ts|js|ps1)$') {
    return @{
      classification = 'TEST_CHANGE'
      classification_source = 'test_source'
    }
  }

  # 6. DOCUMENTATION_CHANGE (Documentation markdown, text files, changelogs)
  if ($normalized -match '(?i)(^|/)(docs?|documentation)(/|$)' -or
      $filename -match '(?i)^(readme|changelog|contributing|security|license|code_of_conduct)(\.(md|mdx|rst|adoc|txt))?$' -or
      $filename -match '(?i)\.(md|mdx|rst|adoc|txt)$') {
    return @{
      classification = 'DOCUMENTATION_CHANGE'
      classification_source = 'documentation'
    }
  }

  # 7. PRODUCT_CHANGE (Implementation source code, application assets, configuration)
  if ($filename -match '(?i)\.(ts|tsx|js|jsx|mjs|cjs|json|yaml|yml|toml|xml|html|htm|css|scss|sass|less|vue|svelte|py|cs|java|kt|scala|go|rs|c|cpp|h|hpp|ps1|psm1|psd1|sh|bash|sql|graphql|proto)$') {
    return @{
      classification = 'PRODUCT_CHANGE'
      classification_source = 'product_source'
    }
  }

  # 8. Fallback: UNKNOWN
  return @{
    classification = 'UNKNOWN'
    classification_source = 'default_fallback'
  }
}

function Test-AgentHubArtifactScopeRelevance {
  param(
    [string]$Classification,
    [string]$TrackedState
  )
  # Invariant: If a file is intentionally tracked by Git, it is ALWAYS scope-relevant
  if ($TrackedState -eq 'TRACKED') {
    return $true
  }

  # Disposable runtime/build/dependency/evidence artifacts that are UNTRACKED or IGNORED are NOT scope-relevant
  switch ($Classification) {
    'DEPENDENCY_ARTIFACT' { return $false }
    'BUILD_ARTIFACT'      { return $false }
    'TEST_ARTIFACT'       { return $false }
    'AGENTHUB_EVIDENCE'   { return $false }
    'RUNTIME_ARTIFACT'    { return $false }
    default               { return $true }  # PRODUCT_CHANGE, TEST_CHANGE, DOCUMENTATION_CHANGE, UNKNOWN are scope-relevant
  }
}

function Get-AgentHubArtifactClassification {
  param(
    [string]$Path,
    [string]$RepositoryPath = '',
    [string]$TrackedState = '',
    $Contract = $null,
    $EnvironmentDiscovery = $null
  )
  $normalized = ConvertTo-AgentHubCanonicalPath $Path
  $kind = Get-AgentHubPathClassification -Path $normalized -EnvironmentDiscovery $EnvironmentDiscovery
  $resolvedTrackedState = Get-AgentHubTrackedState -Path $normalized -RepositoryPath $RepositoryPath -ExplicitTrackedState $TrackedState
  $scopeRelevant = Test-AgentHubArtifactScopeRelevance -Classification $kind.classification -TrackedState $resolvedTrackedState

  $decision = 'UNSPECIFIED'
  if (-not $scopeRelevant) {
    $decision = 'DISPOSABLE_IGNORED'
  } elseif ($null -ne $Contract -and $null -ne $Contract.scope) {
    # Check against contract scope
    $isForbidden = $false
    if ($Contract.scope.forbidden) {
      $isForbidden = [bool]($Contract.scope.forbidden | Where-Object { $normalized -like (ConvertTo-AgentHubCanonicalPath $_) })
    }
    $isAllowed = $false
    if (-not $isForbidden -and $Contract.scope.allowed) {
      $isAllowed = [bool]($Contract.scope.allowed | Where-Object { $normalized -like (ConvertTo-AgentHubCanonicalPath $_) })
    }

    if ($isAllowed) {
      switch ($kind.classification) {
        'PRODUCT_CHANGE'       { $decision = 'AUTHORIZED_PRODUCT' }
        'TEST_CHANGE'          { $decision = 'AUTHORIZED_TEST' }
        'DOCUMENTATION_CHANGE' { $decision = 'AUTHORIZED_DOCUMENTATION' }
        'UNKNOWN'              { $decision = 'AUTHORIZED_UNKNOWN' }
        default                { $decision = 'AUTHORIZED' }
      }
    } else {
      $decision = 'SCOPE_VIOLATION'
    }
  }

  [pscustomobject]@{
    path                  = $normalized
    classification        = $kind.classification
    tracked_state         = $resolvedTrackedState
    classification_source = $kind.classification_source
    scope_relevant        = $scopeRelevant
    scope_decision        = $decision
  }
}

Export-ModuleMember -Function `
  ConvertTo-AgentHubCanonicalPath, `
  Get-AgentHubTrackedState, `
  Get-AgentHubPathClassification, `
  Test-AgentHubArtifactScopeRelevance, `
  Get-AgentHubArtifactClassification
