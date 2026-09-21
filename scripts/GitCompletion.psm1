# GitCompletion.psm1
# Deterministic Minimal Git Completion for AgentHub P0 Control Plane

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ArtifactClassification.psm1') -Global -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'RepositoryResolution.psm1') -Global -Force -DisableNameChecking

function Test-AgentHubGitCompletionPreconditions {
  param(
    [Parameter(Mandatory)][string]$WorktreePath,
    [Parameter(Mandatory)]$Contract,
    $ValidationSummary = $null,
    $Classification = $null,
    $GuardrailReport = $null
  )
  $blockers = [System.Collections.Generic.List[string]]::new()

  # 1. Verify AgentHub owns the worktree
  $taskId = if ($Contract -and $Contract.task -and $Contract.task.id) { $Contract.task.id } else { '' }
  $ownership = Test-AgentHubWorktreeOwnership -WorktreePath $WorktreePath -ExpectedTaskId $taskId
  if (-not $ownership.is_agenthub_worktree -or -not $ownership.matches_task) {
    $blockers.Add("WORKTREE_OWNERSHIP_INVALID: $($ownership.detail)")
  }

  # 2. Verify Git repository state
  if (-not (Test-Path -LiteralPath (Join-Path $WorktreePath '.git'))) {
    $blockers.Add('NOT_A_GIT_REPOSITORY')
  } else {
    # Check for in-progress rebase/merge/bisect
    $gitDir = git -C $WorktreePath rev-parse --git-dir 2>$null
    if ($gitDir) {
      if (-not [IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $WorktreePath $gitDir }
      if ((Test-Path (Join-Path $gitDir 'MERGE_HEAD')) -or (Test-Path (Join-Path $gitDir 'REBASE_HEAD')) -or (Test-Path (Join-Path $gitDir 'BISECT_LOG'))) {
        $blockers.Add('REPOSITORY_STATE_DIRTY_OR_CONFLICTING')
      }
    }
  }

  # 3. Verify branch belongs to current AgentHub task
  $branchRaw = git -C $WorktreePath rev-parse --abbrev-ref HEAD 2>$null
  $currentBranch = if ($branchRaw) { ($branchRaw | Out-String).Trim() } else { '' }
  $expectedBranch = if ($Contract -and $Contract.ownership -and $Contract.ownership.branch) { $Contract.ownership.branch } else { '' }
  if ([string]::IsNullOrWhiteSpace($expectedBranch) -or $currentBranch -ne $expectedBranch) {
    $blockers.Add("BRANCH_OWNERSHIP_MISMATCH: Worktree on branch '$currentBranch', expected '$expectedBranch'")
  }

  # 4. Refuse if validation != GO
  if ($null -eq $ValidationSummary -or $ValidationSummary.overall_status -ne 'GO') {
    $valStatus = if ($ValidationSummary) { $ValidationSummary.overall_status } else { 'NONE' }
    $blockers.Add("VALIDATION_NOT_GO: Status is '$valStatus'")
  }

  # 5. Refuse if scope violation exists
  if ($null -eq $Classification -or -not $Classification.scope_valid -or ($Classification.invalid_files -and $Classification.invalid_files.Count -gt 0)) {
    $invalidCount = if ($Classification -and $Classification.invalid_files) { $Classification.invalid_files.Count } else { -1 }
    $blockers.Add("SCOPE_VIOLATION_PRESENT: $invalidCount invalid files detected")
  }

  # 6. Refuse if no progress detected
  if ($null -eq $Classification -or -not $Classification.progress_detected) {
    $blockers.Add('NO_VALID_PROGRESS_DETECTED')
  }

  # 7. Refuse if critical guardrail failure exists
  if ($GuardrailReport -and $GuardrailReport.new_regression_count -gt 0) {
    $blockers.Add("GUARDRAIL_REGRESSION: $($GuardrailReport.new_regression_count) new regressions")
  }

  $isEligible = ($blockers.Count -eq 0)
  return [pscustomobject]@{
    is_eligible = $isEligible
    reason      = if ($isEligible) { 'READY_FOR_COMPLETION' } else { ($blockers -join '; ') }
    blockers    = @($blockers)
  }
}

function Invoke-AgentHubGitCompletion {
  param(
    [Parameter(Mandatory)][string]$WorktreePath,
    [Parameter(Mandatory)]$Contract,
    $ValidationSummary = $null,
    $Classification = $null,
    $GuardrailReport = $null,
    $Specification = $null
  )

  # Check all invariants (Fail Closed)
  $preconditions = Test-AgentHubGitCompletionPreconditions `
    -WorktreePath $WorktreePath `
    -Contract $Contract `
    -ValidationSummary $ValidationSummary `
    -Classification $Classification `
    -GuardrailReport $GuardrailReport

  if (-not $preconditions.is_eligible) {
    return [pscustomobject]@{
      completed         = $false
      branch            = if ($Contract -and $Contract.ownership) { $Contract.ownership.branch } else { $null }
      commit_sha        = $null
      committed_paths   = @()
      excluded_paths    = @()
      validation_status = if ($ValidationSummary) { $ValidationSummary.overall_status } else { 'UNKNOWN' }
      guardrail_status  = if ($GuardrailReport -and $GuardrailReport.new_regression_count -eq 0) { 'PASSED' } else { 'FAILED' }
      worktree_identity = $WorktreePath
      refusal_reason    = $preconditions.reason
      blockers          = $preconditions.blockers
    }
  }

  # Stage ONLY authorized scope-relevant files
  # Obtain raw worktree status
  $rawStatus = @(git -C $WorktreePath status --porcelain -uall 2>&1 | ForEach-Object {
    if ($_.Length -gt 3) { $_.Substring(3).Trim().Replace('\','/') }
  } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

  $committedPaths = [System.Collections.Generic.List[string]]::new()
  $excludedPaths = [System.Collections.Generic.List[string]]::new()

  foreach ($relPath in $rawStatus) {
    # Check if AgentHub internal file
    if ($relPath.StartsWith('.agenthub') -or $relPath -eq 'TASK_CONTRACT.json') {
      $excludedPaths.Add($relPath)
      continue
    }

    $artClass = Get-AgentHubArtifactClassification -Path $relPath -RepositoryPath $WorktreePath -Contract $Contract
    if ($artClass.scope_relevant -and $artClass.scope_decision -in @('AUTHORIZED_PRODUCT', 'AUTHORIZED_TEST', 'AUTHORIZED_DOCS')) {
      $committedPaths.Add($relPath)
    } else {
      $excludedPaths.Add($relPath)
    }
  }

  if ($committedPaths.Count -eq 0) {
    return [pscustomobject]@{
      completed         = $false
      branch            = $Contract.ownership.branch
      commit_sha        = $null
      committed_paths   = @()
      excluded_paths    = @($excludedPaths)
      validation_status = $ValidationSummary.overall_status
      guardrail_status  = 'PASSED'
      worktree_identity = $WorktreePath
      refusal_reason    = 'NO_AUTHORIZED_FILES_TO_STAGE'
      blockers          = @('NO_AUTHORIZED_FILES_TO_STAGE')
    }
  }

  # Reset index first to avoid any accidental staging
  git -C $WorktreePath reset -q 2>&1 | Out-Null

  # Stage authorized paths
  foreach ($path in $committedPaths) {
    git -C $WorktreePath add -- $path 2>&1 | Out-Null
  }

  # Verify cached index matches ONLY committed paths
  $staged = @(git -C $WorktreePath diff --cached --name-only 2>&1 | ForEach-Object { $_.Trim().Replace('\','/') })
  foreach ($s in $staged) {
    if ($s -notin $committedPaths) {
      # Emergency abort if an excluded file was somehow staged
      git -C $WorktreePath reset -q 2>&1 | Out-Null
      return [pscustomobject]@{
        completed         = $false
        branch            = $Contract.ownership.branch
        commit_sha        = $null
        committed_paths   = @()
        excluded_paths    = @($excludedPaths)
        validation_status = $ValidationSummary.overall_status
        guardrail_status  = 'PASSED'
        worktree_identity = $WorktreePath
        refusal_reason    = "UNAUTHORIZED_FILE_STAGED: $s"
        blockers          = @("UNAUTHORIZED_FILE_STAGED: $s")
      }
    }
  }

  # Format deterministic commit message
  $taskId = $Contract.task.id
  $role = if ($Contract.assignment -and $Contract.assignment.role) { $Contract.assignment.role } else { 'implementer' }
  $engine = if ($Specification -and $Specification.engine) { $Specification.engine } else { 'mock' }
  $valStatus = $ValidationSummary.overall_status
  $issue = if ($Contract.task -and $Contract.task.issue) { $Contract.task.issue } else { 'task implementation' }

  $commitLines = @(
    "[$taskId] $issue",
    "",
    "Task-Id: $taskId",
    "Role: $role",
    "Engine: $engine",
    "Validation: $valStatus"
  )
  $commitMsg = $commitLines -join "`n"

  # Commit locally
  git -C $WorktreePath commit -m $commitMsg -q 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      completed         = $false
      branch            = $Contract.ownership.branch
      commit_sha        = $null
      committed_paths   = @()
      excluded_paths    = @($excludedPaths)
      validation_status = $ValidationSummary.overall_status
      guardrail_status  = 'PASSED'
      worktree_identity = $WorktreePath
      refusal_reason    = 'GIT_COMMIT_FAILED'
      blockers          = @('GIT_COMMIT_FAILED')
    }
  }

  $commitSha = (git -C $WorktreePath rev-parse HEAD 2>&1).Trim()

  return [pscustomobject]@{
    completed         = $true
    branch            = $Contract.ownership.branch
    commit_sha        = $commitSha
    committed_paths   = @($committedPaths)
    excluded_paths    = @($excludedPaths)
    validation_status = $valStatus
    guardrail_status  = 'PASSED'
    worktree_identity = $WorktreePath
    refusal_reason    = $null
    blockers          = @()
  }
}

Export-ModuleMember -Function Test-AgentHubGitCompletionPreconditions, Invoke-AgentHubGitCompletion
