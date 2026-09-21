$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\scripts\RepositoryResolution.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\scripts\ExecutionGate.psm1') -Force -DisableNameChecking

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function New-TestGitRepo {
  $path = Join-Path $env:TEMP ('agenthub-repo-res-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $path | Out-Null
  git init -q $path
  git -C $path config user.email test@example.invalid
  git -C $path config user.name test
  Set-Content -LiteralPath (Join-Path $path 'README.md') '# Test Repository'
  git -C $path add .
  git -C $path commit -qm 'initial commit'
  return $path
}

function New-TestContract([string]$Repository) {
  @{
    schema_version = 2
    task = @{ id = ('repo-test-' + [guid]::NewGuid().ToString('N')); source = 'test'; repository = $Repository; issue = $null }
    goal = 'Repository resolution test'
    assignment = @{ role = 'implementer'; engine = 'codex' }
    state = 'READY'
    scope = @{ bounded_context = 'test'; allowed = @('**'); forbidden = @('AGENTS.md', '.git/**') }
    permissions = @{ filesystem = 'scoped-write'; git_write = $true; github_write = $true; merge = $false; production = 'denied' }
    ownership = @{ task = 'repo-test'; branch = ('feature/test-' + [guid]::NewGuid().ToString('N')); bounded_context = 'test'; files = @('**'); migrations = @() }
    acceptance_criteria = @()
    verification = @{ build = 'NOT_RUN'; lint = 'NOT_RUN'; unit = 'NOT_RUN'; integration = 'NOT_APPLICABLE'; e2e = 'NOT_APPLICABLE'; guardrails = 'NOT_RUN'; ci = 'NOT_RUN' }
    evidence = @{ commit_sha = $null; changed_files = @(); test_results = @(); build_result = $null; playwright = $null; ci = $null; pull_request = $null }
    handoff = @{ target_role = 'human'; reason = 'test' }
    timestamps = @{ created = '2026-09-21T00:00:00Z'; updated = '2026-09-21T00:00:00Z' }
  }
}

# -------------------------------------------------------------
# Case A: Explicit valid repository -> resolved
# -------------------------------------------------------------
$repoA = New-TestGitRepo
try {
  $contractA = New-TestContract $repoA
  $resA = Resolve-AgentHubRepositoryTarget -Contract $contractA
  Assert ($resA.status -eq 'RESOLVED') 'A: Valid repository was not resolved'
  Assert ($resA.identity.is_git_repository -eq $true) 'A: Valid repository not marked as git'
  Assert ($resA.identity.head_sha.Length -eq 40) 'A: Valid HEAD SHA not extracted'
} finally { Remove-Item -LiteralPath $repoA -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case B: Nonexistent repository -> BLOCKED
# -------------------------------------------------------------
$nonexistent = Join-Path $env:TEMP ('agenthub-nonexistent-' + [guid]::NewGuid().ToString('N'))
$contractB = New-TestContract $nonexistent
$resB = Resolve-AgentHubRepositoryTarget -Contract $contractB
Assert ($resB.status -eq 'BLOCKED') 'B: Nonexistent repository was not BLOCKED'

# -------------------------------------------------------------
# Case C: Path exists but is not Git -> BLOCKED
# -------------------------------------------------------------
$notGit = Join-Path $env:TEMP ('agenthub-notgit-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $notGit | Out-Null
try {
  Set-Content -LiteralPath (Join-Path $notGit 'notes.txt') 'plain folder'
  $contractC = New-TestContract $notGit
  $resC = Resolve-AgentHubRepositoryTarget -Contract $contractC
  Assert ($resC.status -eq 'BLOCKED') 'C: Non-git directory was not BLOCKED'
} finally { Remove-Item -LiteralPath $notGit -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case D: Expected remote matches -> PASS
# -------------------------------------------------------------
$repoD = New-TestGitRepo
try {
  git -C $repoD remote add origin 'https://github.com/azfalot/agentic-development-platform.git'
  $contractD = New-TestContract $repoD
  $contractD.task.expected_repository_identity = 'github.com/azfalot/agentic-development-platform'
  $resD = Resolve-AgentHubRepositoryTarget -Contract $contractD
  Assert ($resD.status -eq 'RESOLVED') 'D: Matching expected remote identity failed resolution'
  Assert ($resD.identity.repository_identity -eq 'github.com/azfalot/agentic-development-platform') 'D: Identity normalization mismatch'
} finally { Remove-Item -LiteralPath $repoD -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case E: Expected repository identity mismatch -> BLOCKED
# -------------------------------------------------------------
$repoE = New-TestGitRepo
try {
  git -C $repoE remote add origin 'https://github.com/other-org/other-repo.git'
  $contractE = New-TestContract $repoE
  $contractE.task.expected_repository_identity = 'github.com/expected-org/expected-repo'
  $resE = Resolve-AgentHubRepositoryTarget -Contract $contractE
  Assert ($resE.status -eq 'BLOCKED') 'E: Mismatched expected repository identity did not BLOCK'
} finally { Remove-Item -LiteralPath $repoE -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case F: Expected base branch exists -> PASS
# -------------------------------------------------------------
$repoF = New-TestGitRepo
try {
  git -C $repoF checkout -qb 'release/v1.0'
  Set-Content -LiteralPath (Join-Path $repoF 'release.txt') 'release notes'
  git -C $repoF add .
  git -C $repoF commit -qm 'release commit'
  git -C $repoF checkout -qb 'main'
  $contractF = New-TestContract $repoF
  $contractF.ownership.base_branch = 'release/v1.0'
  $resF = Resolve-AgentHubRepositoryTarget -Contract $contractF
  Assert ($resF.status -eq 'RESOLVED') 'F: Existing base branch failed resolution'
  Assert ($resF.identity.expected_base_branch -eq 'release/v1.0') 'F: Base branch identity mismatch'
  Assert ([bool]$resF.identity.base_sha) 'F: Base branch SHA was not resolved'
} finally { Remove-Item -LiteralPath $repoF -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case G: Missing expected base branch -> BLOCKED
# -------------------------------------------------------------
$repoG = New-TestGitRepo
try {
  $contractG = New-TestContract $repoG
  $contractG.ownership.base_branch = 'non-existent-feature-branch-xyz'
  $resG = Resolve-AgentHubRepositoryTarget -Contract $contractG
  Assert ($resG.status -eq 'BLOCKED') 'G: Missing expected base branch did not BLOCK'
} finally { Remove-Item -LiteralPath $repoG -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case H: Dirty repository detected accurately
# -------------------------------------------------------------
$repoH = New-TestGitRepo
try {
  $cleanId = Get-RepositoryIdentity -RepositoryPath $repoH
  Assert ($cleanId.dirty -eq $false) 'H: Clean repository reported as dirty'
  Set-Content -LiteralPath (Join-Path $repoH 'uncommitted.txt') 'dirty file'
  $dirtyId = Get-RepositoryIdentity -RepositoryPath $repoH
  Assert ($dirtyId.dirty -eq $true) 'H: Uncommitted change not detected as dirty'
} finally { Remove-Item -LiteralPath $repoH -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case I: Detached HEAD detected accurately
# -------------------------------------------------------------
$repoI = New-TestGitRepo
try {
  $headSha = (git -C $repoI rev-parse HEAD).Trim()
  git -C $repoI checkout -q $headSha
  $detachedId = Get-RepositoryIdentity -RepositoryPath $repoI
  Assert ($detachedId.detached_head -eq $true) 'I: Detached HEAD was not detected'
  Assert ($detachedId.current_branch -eq 'HEAD') 'I: Detached branch name was not HEAD'
} finally { Remove-Item -LiteralPath $repoI -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case J: Git worktree recognized
# -------------------------------------------------------------
$repoJ = New-TestGitRepo
$wtJ = Join-Path $env:TEMP ('agenthub-wt-' + [guid]::NewGuid().ToString('N'))
try {
  $null = git -C $repoJ worktree add -q $wtJ -b 'test-wt-branch' 2>&1
  $mainId = Get-RepositoryIdentity -RepositoryPath $repoJ
  $wtId = Get-RepositoryIdentity -RepositoryPath $wtJ
  Assert ($mainId.worktree -eq $false) 'J: Main repo incorrectly identified as linked worktree'
  Assert ($wtId.worktree -eq $true) 'J: Linked worktree was not recognized as worktree'
} finally {
  if (Test-Path -LiteralPath $wtJ) { Remove-Item -LiteralPath $wtJ -Recurse -Force -ErrorAction SilentlyContinue }
  $null = git -C $repoJ worktree prune 2>&1
  Remove-Item -LiteralPath $repoJ -Recurse -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------
# Case K: AgentHub worktree ownership record created correctly
# -------------------------------------------------------------
$repoK = New-TestGitRepo
$wtK = Join-Path $env:TEMP ('agenthub-wt-k-' + [guid]::NewGuid().ToString('N'))
try {
  $null = git -C $repoK worktree add -q $wtK -b 'test-wt-k' 2>&1
  $rec = New-AgentHubWorktreeOwnershipRecord -WorktreePath $wtK -TaskId 'task-k-123' -SourceRepository $repoK -SourceHead 'a1b2c3' -SourceBase 'main' -CreatedBranch 'test-wt-k'
  Assert ($rec.task_id -eq 'task-k-123') 'K: Ownership record task_id mismatch'
  $checkK = Test-AgentHubWorktreeOwnership -WorktreePath $wtK -ExpectedTaskId 'task-k-123'
  Assert ($checkK.is_agenthub_worktree -eq $true) 'K: Ownership test did not recognize AgentHub worktree'
  Assert ($checkK.matches_task -eq $true) 'K: Ownership test did not match expected task'
} finally {
  if (Test-Path -LiteralPath $wtK) { Remove-Item -LiteralPath $wtK -Recurse -Force -ErrorAction SilentlyContinue }
  $null = git -C $repoK worktree prune 2>&1
  Remove-Item -LiteralPath $repoK -Recurse -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------
# Case L: Foreign worktree is not claimed by AgentHub
# -------------------------------------------------------------
$repoL = New-TestGitRepo
$wtL = Join-Path $env:TEMP ('foreign-wt-' + [guid]::NewGuid().ToString('N'))
try {
  $null = git -C $repoL worktree add -q $wtL -b 'user-manual-worktree' 2>&1
  # No AgentHub ownership record written
  $checkL = Test-AgentHubWorktreeOwnership -WorktreePath $wtL -ExpectedTaskId 'task-any'
  Assert ($checkL.is_agenthub_worktree -eq $false) 'L: Foreign worktree was claimed as AgentHub worktree'
  Assert ($checkL.creator -eq 'foreign') 'L: Creator was not marked foreign'
} finally {
  if (Test-Path -LiteralPath $wtL) { Remove-Item -LiteralPath $wtL -Recurse -Force -ErrorAction SilentlyContinue }
  $null = git -C $repoL worktree prune 2>&1
  Remove-Item -LiteralPath $repoL -Recurse -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------
# Case M: Equivalent supported HTTPS/SSH remote forms normalize to same identity
# -------------------------------------------------------------
$httpsId = Get-NormalizedRepositoryIdentity 'https://github.com/example-org/sample-service.git'
$sshId = Get-NormalizedRepositoryIdentity 'git@github.com:example-org/sample-service.git'
$sshProtoId = Get-NormalizedRepositoryIdentity 'ssh://git@github.com/example-org/sample-service.git'
$httpId = Get-NormalizedRepositoryIdentity 'http://github.com/example-org/sample-service'
Assert ($httpsId -eq 'github.com/example-org/sample-service') 'M: HTTPS URL did not normalize correctly'
Assert ($sshId -eq 'github.com/example-org/sample-service') 'M: SSH URL did not normalize correctly'
Assert ($sshProtoId -eq 'github.com/example-org/sample-service') 'M: SSH protocol URL did not normalize correctly'
Assert ($httpId -eq 'github.com/example-org/sample-service') 'M: HTTP URL did not normalize correctly'
Assert ($httpsId -eq $sshId) 'M: HTTPS and SSH identities did not match'

# -------------------------------------------------------------
# Case N: Two local clones of same logical repo without explicit target -> AMBIGUOUS BLOCK
# -------------------------------------------------------------
$cloneN1 = New-TestGitRepo
$cloneN2 = New-TestGitRepo
try {
  git -C $cloneN1 remote add origin 'https://github.com/example-org/sample-service.git'
  git -C $cloneN2 remote add origin 'git@github.com:example-org/sample-service.git'
  $contractN = @{ schema_version = 2; task = @{ id = 'ambiguous-task'; source = 'test'; repository = ''; issue = $null } }
  $resN = Resolve-AgentHubRepositoryTarget -Contract $contractN -CandidateRepositories @($cloneN1, $cloneN2)
  Assert ($resN.status -eq 'BLOCKED') 'N: Ambiguous duplicate clones did not BLOCK'
  Assert ($resN.reason -match 'AMBIGUOUS_REPOSITORY') 'N: Reason did not state AMBIGUOUS_REPOSITORY'
} finally {
  Remove-Item -LiteralPath $cloneN1 -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $cloneN2 -Recurse -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------
# Case O: Explicit Task Contract repository wins over any other local clone
# -------------------------------------------------------------
$cloneO1 = New-TestGitRepo
$cloneO2 = New-TestGitRepo
try {
  git -C $cloneO1 remote add origin 'https://github.com/example-org/sample-service.git'
  git -C $cloneO2 remote add origin 'git@github.com:example-org/sample-service.git'
  $contractO = New-TestContract $cloneO1
  $resO = Resolve-AgentHubRepositoryTarget -Contract $contractO -CandidateRepositories @($cloneO1, $cloneO2)
  Assert ($resO.status -eq 'RESOLVED') 'O: Explicit contract repository failed to resolve'
  Assert ($resO.repository_path -eq (Resolve-Path $cloneO1).Path) 'O: Explicit contract repository was not chosen'
  Assert ($resO.selection_source -eq 'task_contract') 'O: Selection source was not task_contract'
} finally {
  Remove-Item -LiteralPath $cloneO1 -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $cloneO2 -Recurse -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------
# Case P: Incompatible sandbox/filesystem blocks before worktree/agent
# -------------------------------------------------------------
$nonExistentPathP = 'Z:\__inaccessible_drive_test_p__' + [guid]::NewGuid().ToString('N')
$contractP = New-TestContract $nonExistentPathP
$resP = Resolve-AgentHubRepositoryTarget -Contract $contractP
Assert ($resP.status -eq 'BLOCKED') 'P: Incompatible path did not BLOCK repository target'

# -------------------------------------------------------------
# Case Q & R: BLOCKED repository consumes zero execution budget & zero models
# -------------------------------------------------------------
$blockedRepo = Join-Path $env:TEMP ('agenthub-blocked-' + [guid]::NewGuid().ToString('N'))
$contractQR = New-TestContract $blockedRepo
$contractQRPath = Join-Path $env:TEMP ('contract-qr-' + [guid]::NewGuid().ToString('N') + '.json')
$contractQR | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $contractQRPath -Encoding utf8

$hub = Join-Path $PSScriptRoot '..\scripts\agenthub.ps1'
$ErrorActionPreference = 'Continue'
$hubOutput = & pwsh -NoProfile -File $hub run $contractQRPath 2>&1
$hubExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

Assert ($hubExit -ne 0) 'Q: Blocked repository execution unexpectedly succeeded'
Assert (($hubOutput | Out-String) -match 'REPOSITORY_VALIDATION_BLOCKED|REPOSITORY_RESOLUTION_BLOCKED') 'Q: Output did not indicate repository blocked'

# Check that no execution budget was initialized or consumed
$budgetPathQR = Get-TaskExecutionBudgetPath -Repository $blockedRepo -TaskId $contractQR.task.id
Assert (-not (Test-Path -LiteralPath $budgetPathQR)) 'Q: Blocked repository created or consumed an execution budget'

Remove-Item -LiteralPath $contractQRPath -Force -ErrorAction SilentlyContinue

Write-Output 'Repository resolution matrix A-R passed without model invocation.'
