Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ProjectEnvironmentDiscovery.psm1') -Force

function Get-NormalizedRepositoryIdentity {
  [CmdletBinding()]
  param([string]$RemoteUrl)
  if ([string]::IsNullOrWhiteSpace($RemoteUrl)) { return $null }
  $url = $RemoteUrl.Trim()
  
  # Local file paths or file URLs
  if ($url -match '^file:///(.+)$') {
    return 'local:' + $Matches[1].Replace('\', '/').Trim('/').ToLowerInvariant()
  }
  if ($url -match '^[a-zA-Z]:[\\/]') {
    return 'local:' + $url.Replace('\', '/').Trim('/').ToLowerInvariant()
  }
  
  # HTTP / HTTPS URLs: https://host/owner/repo.git
  if ($url -match '^https?://([^/]+)/(.+?)(?:\.git)?$') {
    $hostName = $Matches[1].ToLowerInvariant()
    $repoPath = $Matches[2].Trim('/').ToLowerInvariant()
    return "$hostName/$repoPath"
  }

  # SSH URLs: git@host:owner/repo.git or ssh://git@host/owner/repo.git
  if ($url -match '^(?:ssh://)?(?:[^@]+@)?([^:/]+)(?::\d+)?[:/](.+?)(?:\.git)?$') {
    $hostName = $Matches[1].ToLowerInvariant()
    $repoPath = $Matches[2].Trim('/').ToLowerInvariant()
    return "$hostName/$repoPath"
  }
  
  return $url.ToLowerInvariant()
}

function Get-RepositoryIdentity {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RepositoryPath,
    [hashtable]$Contract = $null
  )

  $resolvedPath = $null
  try {
    if (Test-Path -LiteralPath $RepositoryPath) {
      $resolvedPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
    } else {
      $resolvedPath = $RepositoryPath
    }
  } catch {
    $resolvedPath = $RepositoryPath
  }

  $exists = $false
  try { $exists = Test-Path -LiteralPath $resolvedPath } catch { $exists = $false }
  if (-not $exists) {
    return [pscustomobject]@{
      repository_path = $resolvedPath
      git_common_dir = $null
      remote_name = $null
      remote_url = $null
      repository_identity = $null
      current_branch = $null
      head_sha = $null
      expected_base_branch = $null
      base_sha = $null
      dirty = $false
      worktree = $false
      detached_head = $false
      shallow_repository = $false
      is_git_repository = $false
      detail = "configured repository path does not exist: $resolvedPath"
    }
  }

  $isGit = $false
  try {
    $isWorkTree = (git -C $resolvedPath rev-parse --is-inside-work-tree 2>&1 | Out-String).Trim()
    $isGit = ($LASTEXITCODE -eq 0 -and $isWorkTree -eq 'true')
  } catch { $isGit = $false }

  if (-not $isGit) {
    return [pscustomobject]@{
      repository_path = $resolvedPath
      git_common_dir = $null
      remote_name = $null
      remote_url = $null
      repository_identity = $null
      current_branch = $null
      head_sha = $null
      expected_base_branch = $null
      base_sha = $null
      dirty = $false
      worktree = $false
      detached_head = $false
      shallow_repository = $false
      is_git_repository = $false
      detail = "path is not a valid git repository or worktree: $resolvedPath"
    }
  }

  # Discover git common dir and worktree status
  $gitDir = $null
  $gitCommonDir = $null
  try {
    $gitDir = (git -C $resolvedPath rev-parse --git-dir 2>&1 | Out-String).Trim()
    $gitCommonDir = (git -C $resolvedPath rev-parse --git-common-dir 2>&1 | Out-String).Trim()
  } catch {}

  $isWorktree = $false
  if ($gitDir -and $gitCommonDir) {
    $isWorktree = ($gitDir -ne $gitCommonDir -and $gitDir -ne '.git')
  }

  # Discover remotes
  $remotes = @()
  try {
    $remotes = @(git -C $resolvedPath remote | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  } catch {}

  $remoteName = if ($remotes -contains 'origin') { 'origin' } elseif ($remotes.Count -gt 0) { $remotes[0] } else { $null }
  $remoteUrl = $null
  if ($remoteName) {
    try {
      $remoteUrl = (git -C $resolvedPath remote get-url $remoteName 2>&1 | Out-String).Trim()
      if ($LASTEXITCODE -ne 0) { $remoteUrl = $null }
    } catch { $remoteUrl = $null }
  }

  $repoIdentity = if ($remoteUrl) {
    Get-NormalizedRepositoryIdentity $remoteUrl
  } else {
    'local:' + $resolvedPath.Replace('\', '/').Trim('/').ToLowerInvariant()
  }

  # Discover branch and HEAD
  $currentBranch = $null
  $detachedHead = $false
  try {
    $symRef = (git -C $resolvedPath symbolic-ref --short -q HEAD 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $symRef) {
      $currentBranch = $symRef
      $detachedHead = $false
    } else {
      $currentBranch = 'HEAD'
      $detachedHead = $true
    }
  } catch {
    $currentBranch = 'HEAD'
    $detachedHead = $true
  }

  $headSha = $null
  try {
    $headSha = (git -C $resolvedPath rev-parse HEAD 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $headSha.Length -ne 40) { $headSha = $null }
  } catch { $headSha = $null }

  # Determine expected base branch
  $expectedBaseBranch = $null
  if ($Contract) {
    if ($Contract.ContainsKey('ownership') -and $Contract.ownership -is [hashtable] -and $Contract.ownership.ContainsKey('base_branch') -and $Contract.ownership.base_branch) {
      $expectedBaseBranch = [string]$Contract.ownership.base_branch
    } elseif ($Contract.ContainsKey('scope') -and $Contract.scope -is [hashtable] -and $Contract.scope.ContainsKey('base_branch') -and $Contract.scope.base_branch) {
      $expectedBaseBranch = [string]$Contract.scope.base_branch
    } elseif ($Contract.ContainsKey('task') -and $Contract.task -is [hashtable] -and $Contract.task.ContainsKey('base_branch') -and $Contract.task.base_branch) {
      $expectedBaseBranch = [string]$Contract.task.base_branch
    }
  }
  if (-not $expectedBaseBranch) {
    $expectedBaseBranch = if ($currentBranch -and $currentBranch -ne 'HEAD') { $currentBranch } else { 'main' }
  }

  # Resolve base branch commit SHA
  $baseSha = $null
  if ($expectedBaseBranch) {
    try {
      $resSha = (git -C $resolvedPath rev-parse --verify --quiet "refs/heads/$expectedBaseBranch" 2>&1 | Out-String).Trim()
      if ($LASTEXITCODE -eq 0 -and $resSha.Length -eq 40) {
        $baseSha = $resSha
      } else {
        $resSha2 = (git -C $resolvedPath rev-parse --verify --quiet "$expectedBaseBranch" 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $resSha2.Length -eq 40) {
          $baseSha = $resSha2
        }
      }
    } catch { $baseSha = $null }
  }

  # Dirty state
  $dirty = $false
  try {
    $statusOut = (git -C $resolvedPath status --porcelain 2>&1 | Out-String).Trim()
    $dirty = ($statusOut.Length -gt 0)
  } catch {}

  # Shallow check
  $shallow = $false
  try {
    $shallowStr = (git -C $resolvedPath rev-parse --is-shallow-repository 2>&1 | Out-String).Trim()
    $shallow = ($shallowStr -eq 'true')
  } catch {}

  [pscustomobject]@{
    repository_path = $resolvedPath
    git_common_dir = $gitCommonDir
    remote_name = $remoteName
    remote_url = $remoteUrl
    repository_identity = $repoIdentity
    current_branch = $currentBranch
    head_sha = $headSha
    expected_base_branch = $expectedBaseBranch
    base_sha = $baseSha
    dirty = $dirty
    worktree = $isWorktree
    detached_head = $detachedHead
    shallow_repository = $shallow
    is_git_repository = $true
    detail = 'git repository identity discovered'
  }
}

function Test-RepositorySafetyAndReadiness {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RepositoryPath,
    [hashtable]$Contract = $null
  )

  $identity = Get-RepositoryIdentity -RepositoryPath $RepositoryPath -Contract $Contract
  $checks = [System.Collections.Generic.List[object]]::new()

  # 1. Configured repository exists
  $exists = $identity.is_git_repository -or (Test-Path -LiteralPath $RepositoryPath)
  $checks.Add([pscustomobject]@{
    name = 'repository-exists'
    required = $true
    passed = $exists
    detail = if ($exists) { $identity.repository_path } else { "path not found: $RepositoryPath" }
  })

  # 2. Path is a git repository or worktree
  $checks.Add([pscustomobject]@{
    name = 'git-repository'
    required = $true
    passed = $identity.is_git_repository
    detail = if ($identity.is_git_repository) { 'valid git repository' } else { 'not a git repository' }
  })

  if ($identity.is_git_repository) {
    # 3. Repository identity matches expectation when declared
    $expectedIdentity = $null
    if ($Contract -and $Contract.ContainsKey('task') -and $Contract.task -is [hashtable] -and $Contract.task.ContainsKey('expected_repository_identity')) {
      $expectedIdentity = Get-NormalizedRepositoryIdentity $Contract.task.expected_repository_identity
    } elseif ($Contract -and $Contract.ContainsKey('task') -and $Contract.task -is [hashtable] -and $Contract.task.ContainsKey('expected_remote')) {
      $expectedIdentity = Get-NormalizedRepositoryIdentity $Contract.task.expected_remote
    }

    if ($expectedIdentity) {
      $idMatches = ($identity.repository_identity -eq $expectedIdentity)
      $checks.Add([pscustomobject]@{
        name = 'repository-identity-match'
        required = $true
        passed = $idMatches
        detail = if ($idMatches) { "identity matched: $($identity.repository_identity)" } else { "identity mismatch: expected $expectedIdentity, got $($identity.repository_identity)" }
      })
    }

    # 4. Remote URL structural validity (if remote is configured)
    if ($identity.remote_url) {
      $urlValid = ($identity.remote_url -match '^https?://.+' -or $identity.remote_url -match '^git@.+' -or $identity.remote_url -match '^ssh://.+' -or $identity.remote_url -match '^file://.+')
      $checks.Add([pscustomobject]@{
        name = 'remote-url-valid'
        required = $true
        passed = $urlValid
        detail = $identity.remote_url
      })
    }

    # 5. Expected base branch exists & resolves to a commit
    $baseBranchDeclared = ($Contract -and $Contract.ContainsKey('ownership') -and $Contract.ownership -is [hashtable] -and $Contract.ownership.ContainsKey('base_branch') -and $Contract.ownership.base_branch)
    $hasBaseSha = [bool]($identity.base_sha)
    $checks.Add([pscustomobject]@{
      name = 'expected-base-branch'
      required = [bool]$baseBranchDeclared
      passed = if ($baseBranchDeclared) { $hasBaseSha } else { $true }
      detail = if ($hasBaseSha) { "$($identity.expected_base_branch) -> $($identity.base_sha)" } else { "base branch not found: $($identity.expected_base_branch)" }
    })

    # 6. HEAD is resolvable
    $checks.Add([pscustomobject]@{
      name = 'head-resolvable'
      required = $true
      passed = [bool]($identity.head_sha)
      detail = if ($identity.head_sha) { "HEAD -> $($identity.head_sha)" } else { 'HEAD could not be resolved' }
    })

    # 7. Informational / state probes
    $checks.Add([pscustomobject]@{
      name = 'detached-head'
      required = $false
      passed = (-not $identity.detached_head)
      detail = if ($identity.detached_head) { 'detached HEAD detected' } else { "active branch: $($identity.current_branch)" }
    })

    $checks.Add([pscustomobject]@{
      name = 'dirty-state'
      required = $false
      passed = (-not $identity.dirty)
      detail = if ($identity.dirty) { 'uncommitted changes detected in working tree' } else { 'clean working tree' }
    })

    $checks.Add([pscustomobject]@{
      name = 'worktree-status'
      required = $false
      passed = $true
      detail = if ($identity.worktree) { 'linked worktree' } else { 'main worktree' }
    })
  }

  # 8. Sandbox & filesystem write capability
  $perm = if ($Contract -and $Contract.ContainsKey('permissions') -and $Contract.permissions -is [hashtable] -and $Contract.permissions.ContainsKey('filesystem')) {
    [string]$Contract.permissions.filesystem
  } else {
    'scoped-write'
  }
  $sandbox = Test-EnvironmentSandboxCapability -WorkingDirectory $identity.repository_path -FilesystemPermission $perm
  $checks.Add([pscustomobject]@{
    name = 'sandbox-compatibility'
    required = $true
    passed = ($sandbox.writable -and $sandbox.compatible)
    detail = $sandbox.detail
  })

  $failed = @($checks | Where-Object { $_.required -and -not $_.passed })
  $state = if ($failed.Count -eq 0) { 'READY' } else { 'BLOCKED' }

  [pscustomobject]@{
    state = $state
    passed = ($state -eq 'READY')
    identity = $identity
    checks = @($checks)
    blockers = @($failed)
  }
}

function Resolve-AgentHubRepositoryTarget {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Contract,
    [string]$ProjectConfigurationPath = '',
    [string[]]$CandidateRepositories = @()
  )

  $selectedPath = $null
  $selectionSource = $null

  # Precedence 1: Explicit Task Contract repository
  if ($Contract.ContainsKey('task') -and $Contract.task -is [hashtable] -and $Contract.task.ContainsKey('repository') -and [string]::IsNullOrWhiteSpace($Contract.task.repository) -eq $false) {
    $selectedPath = [string]$Contract.task.repository
    $selectionSource = 'task_contract'
  }
  # Precedence 2: Explicit project configuration
  elseif ($ProjectConfigurationPath -and (Test-Path -LiteralPath $ProjectConfigurationPath)) {
    try {
      $cfg = Get-Content -Raw -LiteralPath $ProjectConfigurationPath | ConvertFrom-Json -AsHashtable
      if ($cfg.ContainsKey('repository') -and $cfg.repository) {
        $selectedPath = [string]$cfg.repository
        $selectionSource = 'project_configuration'
      }
    } catch {}
  }
  # Precedence 3: Unambiguous candidate / current working directory
  elseif ($CandidateRepositories.Count -eq 1) {
    $selectedPath = $CandidateRepositories[0]
    $selectionSource = 'unambiguous_candidate'
  }

  # Multiple candidate ambiguity check: if no explicit contract repository and multiple candidates exist -> BLOCK
  if (-not $selectedPath) {
    if ($CandidateRepositories.Count -gt 1) {
      return [pscustomobject]@{
        status = 'BLOCKED'
        reason = 'AMBIGUOUS_REPOSITORY: multiple candidate repositories discovered without explicit contract target'
        selection_source = 'ambiguous'
        repository_path = $null
        identity = $null
        validation = $null
      }
    }
    return [pscustomobject]@{
      status = 'BLOCKED'
      reason = 'REPOSITORY_UNSPECIFIED: task contract does not specify target repository'
      selection_source = 'none'
      repository_path = $null
      identity = $null
      validation = $null
    }
  }

  # Validate the selected repository target
  $validation = Test-RepositorySafetyAndReadiness -RepositoryPath $selectedPath -Contract $Contract
  if ($validation.state -ne 'READY') {
    $blockersDetail = @($validation.blockers | ForEach-Object { "$($_.name): $($_.detail)" }) -join '; '
    return [pscustomobject]@{
      status = 'BLOCKED'
      reason = "REPOSITORY_VALIDATION_BLOCKED: $blockersDetail"
      selection_source = $selectionSource
      repository_path = $selectedPath
      identity = $validation.identity
      validation = $validation
    }
  }

  [pscustomobject]@{
    status = 'RESOLVED'
    reason = 'canonical repository target resolved and validated'
    selection_source = $selectionSource
    repository_path = $validation.identity.repository_path
    identity = $validation.identity
    validation = $validation
  }
}

function New-AgentHubWorktreeOwnershipRecord {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$WorktreePath,
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][string]$SourceRepository,
    [string]$SourceHead = '',
    [string]$SourceBase = '',
    [string]$CreatedBranch = ''
  )
  $record = @{
    schema_version = 1
    task_id = $TaskId
    source_repository = $SourceRepository
    source_head = $SourceHead
    source_base = $SourceBase
    created_worktree_path = $WorktreePath
    created_branch = $CreatedBranch
    created_at = (Get-Date).ToUniversalTime().ToString('o')
    ownership_state = 'CLAIMED'
    creator = 'AgentHub'
  }
  $path = Join-Path $WorktreePath '.agenthub-worktree-ownership.json'
  $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
  return $record
}

function Test-AgentHubWorktreeOwnership {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$WorktreePath,
    [string]$ExpectedTaskId = ''
  )
  $recordPath = Join-Path $WorktreePath '.agenthub-worktree-ownership.json'
  if (-not (Test-Path -LiteralPath $recordPath)) {
    return [pscustomobject]@{
      is_agenthub_worktree = $false
      matches_task = $false
      task_id = $null
      creator = 'foreign'
      detail = 'no agenthub ownership record found (foreign / user / IDE worktree)'
    }
  }
  try {
    $record = Get-Content -Raw -LiteralPath $recordPath | ConvertFrom-Json -AsHashtable
    $isAgentHub = ($record.ContainsKey('creator') -and $record.creator -eq 'AgentHub')
    $taskId = if ($record.ContainsKey('task_id')) { [string]$record.task_id } else { $null }
    $matches = if ($ExpectedTaskId) { ($taskId -eq $ExpectedTaskId) } else { $true }
    return [pscustomobject]@{
      is_agenthub_worktree = $isAgentHub
      matches_task = $matches
      task_id = $taskId
      creator = if ($isAgentHub) { 'AgentHub' } else { 'foreign' }
      detail = if ($isAgentHub -and $matches) { "valid AgentHub worktree ownership for task $taskId" } else { "ownership mismatch for task $taskId" }
    }
  } catch {
    return [pscustomobject]@{
      is_agenthub_worktree = $false
      matches_task = $false
      task_id = $null
      creator = 'corrupt'
      detail = "corrupt ownership record: $($_.Exception.Message)"
    }
  }
}

Export-ModuleMember -Function Get-NormalizedRepositoryIdentity, Get-RepositoryIdentity, Test-RepositorySafetyAndReadiness, Resolve-AgentHubRepositoryTarget, New-AgentHubWorktreeOwnershipRecord, Test-AgentHubWorktreeOwnership
