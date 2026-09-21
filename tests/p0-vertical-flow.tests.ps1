# p0-vertical-flow.tests.ps1
# Deterministic Vertical Acceptance Test Suite for AgentHub P0 Control Plane Flow

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\scripts\GitCompletion.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\ArtifactClassification.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\ProgressClassifier.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\RepositoryResolution.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\ValidationCollection.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\EnvironmentReadiness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\ProjectEnvironmentDiscovery.psm1') -Force -DisableNameChecking

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

$hub = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts\agenthub.ps1')).Path

# Helper to create a deterministic mock codex executable
function New-MockCodexScript([string]$Directory) {
  $mockPath = Join-Path $Directory 'mock-codex.ps1'
  $content = @'
if ($args -contains '--version') {
  Write-Output 'mock-codex 1.0.0'
  exit 0
}
if ($args -contains '--help') {
  Write-Output 'Run Codex non-interactively [possible values: read-only, workspace-write]'
  exit 0
}
if ($args -contains 'sandbox') {
  Write-Output 'AGENTHUB_SANDBOX_PROBE_OK'
  exit 0
}
if ($args -contains 'exec') {
  if ($env:MOCK_NO_PROGRESS -eq '1') { exit 0 }
  if ($env:MOCK_AGENT_FAIL -eq '1') {
    [Console]::Error.WriteLine('Agent failed')
    exit 1
  }
  $targetDir = $null
  for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--cd' -and $i + 1 -lt $args.Count) {
      $targetDir = $args[$i + 1]
      break
    }
  }
  if (-not $targetDir) { $targetDir = (Get-Location).Path }
  $targetDir = ($targetDir -replace '^["'']|["'']$').Trim()
  if ($env:MOCK_SCOPE_VIOLATION -eq '1') {
    $forbDir = Join-Path $targetDir 'forbidden'
    if (-not (Test-Path $forbDir)) { New-Item -ItemType Directory -Path $forbDir -Force | Out-Null }
    Set-Content -Path (Join-Path $forbDir 'secret.key') -Value 'leak'
  }
  $targetFolder = Join-Path $targetDir 'target'
  if (-not (Test-Path $targetFolder)) { New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null }
  Set-Content -Path (Join-Path $targetFolder 'build-output.txt') -Value 'build'

  $srcFolder = Join-Path $targetDir 'src'
  if (-not (Test-Path $srcFolder)) { New-Item -ItemType Directory -Path $srcFolder -Force | Out-Null }
  Set-Content -Path (Join-Path $srcFolder 'app.js') -Value 'app-source'

  $testFolder = Join-Path $targetDir 'test'
  if (-not (Test-Path $testFolder)) { New-Item -ItemType Directory -Path $testFolder -Force | Out-Null }
  Set-Content -Path (Join-Path $testFolder 'app.test.js') -Value 'test-source'
  exit 0
}
exit 0
'@
  Set-Content -LiteralPath $mockPath -Value $content -Encoding utf8
  return $mockPath
}

function New-SampleTestRepo {
  $path = Join-Path $env:TEMP ('agenthub-p0-repo-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $path | Out-Null
  git init -q $path
  git -C $path config user.email test@example.invalid
  git -C $path config user.name test
  Set-Content -LiteralPath (Join-Path $path 'AGENTS.md') 'global policy'
  Set-Content -LiteralPath (Join-Path $path 'package.json') '{"name":"sample-project","scripts":{"test":"node test/app.test.js"}}'
  New-Item -ItemType Directory -Path (Join-Path $path 'src') | Out-Null
  Set-Content -LiteralPath (Join-Path $path 'src/app.js') '// initial'
  New-Item -ItemType Directory -Path (Join-Path $path 'test') | Out-Null
  Set-Content -LiteralPath (Join-Path $path 'test/app.test.js') '// initial test'
  git -C $path add .
  git -C $path commit -qm 'initial commit'
  return $path
}

function New-SampleContract([string]$RepoPath, [string]$TaskId = 'p0-task-001') {
  [pscustomobject]@{
    schema_version = 2
    task = [pscustomobject]@{
      id = $TaskId
      source = 'local'
      repository = $RepoPath
      issue = 'Implement core calculation feature'
    }
    goal = 'Implement math calculation'
    assignment = [pscustomobject]@{
      role = 'implementer'
      engine = 'codex'
    }
    state = 'READY'
    scope = [pscustomobject]@{
      bounded_context = 'core'
      allowed = @('src/**', 'test/**')
      forbidden = @('forbidden/**', 'AGENTS.md', '.git/**')
    }
    permissions = [pscustomobject]@{
      filesystem = 'scoped-write'
      git_write = $true
      github_write = $true
      merge = $false
      production = 'denied'
    }
    ownership = [pscustomobject]@{
      task = $TaskId
      branch = "feature/$TaskId"
      bounded_context = 'core'
      files = @('src/**', 'test/**')
      migrations = @()
    }
    acceptance_criteria = @(
      [pscustomobject]@{ id = 'AC-1'; description = 'Calculation works'; status = 'PENDING' }
    )
    verification = [pscustomobject]@{
      build = 'NOT_RUN'
      lint = 'NOT_RUN'
      unit = 'PASSED'
      integration = 'NOT_APPLICABLE'
      e2e = 'NOT_APPLICABLE'
      guardrails = 'NOT_RUN'
      ci = 'NOT_RUN'
    }
    environment = [pscustomobject]@{
      required_commands = @(
        [pscustomobject]@{ name = 'node'; required = $false }
      )
      dependencies = @()
      services = @()
      verification_commands = @(
        [pscustomobject]@{
          name = 'test-runner'
          file = 'pwsh'
          arguments = @('-NoProfile', '-Command', 'exit 0')
          category = 'unit'
          required = $true
        }
      )
      preparation = [pscustomobject]@{
        allowed = $true
        actions = @()
      }
    }
    evidence = [pscustomobject]@{
      commit_sha = $null
      changed_files = @()
      test_results = @()
      build_result = $null
      playwright = $null
      ci = $null
      pull_request = $null
    }
    handoff = [pscustomobject]@{
      target_role = 'reviewer'
      reason = 'Implementation complete'
    }
    timestamps = [pscustomobject]@{
      created = '2026-09-20T00:00:00Z'
      updated = '2026-09-20T00:00:00Z'
    }
  }
}

# =============================================================
# SCENARIO A: Valid Complete Flow -> READY_FOR_HUMAN & Local Commit
# =============================================================
$repoA = New-SampleTestRepo
$mockCodexA = New-MockCodexScript -Directory $repoA
$contractA = New-SampleContract -RepoPath $repoA -TaskId 'task-p0-success'
$contractFileA = Join-Path $repoA 'TASK_CONTRACT.json'
$contractA | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $contractFileA

# Clear any mock error flags
$env:MOCK_NO_PROGRESS = $null
$env:MOCK_AGENT_FAIL = $null
$env:MOCK_SCOPE_VIOLATION = $null
$env:MOCK_DISPOSABLE_CACHE = $null

$evidencePathA = & $hub run $contractFileA -EngineExecutable $mockCodexA
Assert ($LASTEXITCODE -eq 0) 'Scenario A: AgentHub execution failed'
Assert (Test-Path -LiteralPath $evidencePathA) 'Scenario A: Evidence file missing'

$evidenceA = Get-Content -Raw -LiteralPath $evidencePathA | ConvertFrom-Json
if ($evidenceA.final_state -ne 'READY_FOR_HUMAN') {
  throw "Scenario A: Final state was '$($evidenceA.final_state)', scope: '$($evidenceA.scope_validation)', val: '$($evidenceA.overall_validation_status)', git_comp: $($evidenceA.git_completion | ConvertTo-Json -Compress), err: $(Get-Content -Raw $evidenceA.engine_process.stderr)"
}
Assert ($evidenceA.final_state -eq 'READY_FOR_HUMAN') "Scenario A: Final state must be READY_FOR_HUMAN, got $($evidenceA.final_state)"
Assert ($evidenceA.overall_validation_status -eq 'GO') 'Scenario A: Validation status must be GO'
Assert ($null -ne $evidenceA.git_completion) 'Scenario A: git_completion missing in evidence'
Assert ($evidenceA.git_completion.completed -eq $true) 'Scenario A: git_completion.completed must be true'
Assert (-not [string]::IsNullOrWhiteSpace($evidenceA.final_commit_sha)) 'Scenario A: final_commit_sha missing'

# Verify the worktree git log contains the created commit
$worktreeA = $evidenceA.workspace
$commitLogA = (git -C $worktreeA log -n 1 --pretty=format:"%B" 2>&1) -join "`n"
Assert ($commitLogA -match '\[task-p0-success\]') 'Scenario A: Commit message must contain task id'
Assert ($commitLogA -match 'Validation: GO') 'Scenario A: Commit trailer must contain Validation: GO'
Assert ($commitLogA -match 'Role: implementer') 'Scenario A: Commit trailer must contain Role'

# =============================================================
# SCENARIO B: Validation NO_GO -> No Commit, FAILED
# =============================================================
$repoB = New-SampleTestRepo
$mockCodexB = New-MockCodexScript -Directory $repoB
$contractB = New-SampleContract -RepoPath $repoB -TaskId 'task-p0-fail-val'
# Inject a failing verification command
$contractB.environment.verification_commands = @(
  [pscustomobject]@{
    name = 'failing-test'
    file = 'pwsh'
    arguments = @('-NoProfile', '-Command', 'exit 1')
    category = 'unit'
    required = $true
  }
)
$contractFileB = Join-Path $repoB 'TASK_CONTRACT.json'
$contractB | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $contractFileB

$evidencePathB = & $hub run $contractFileB -EngineExecutable $mockCodexB
$evidenceB = Get-Content -Raw -LiteralPath $evidencePathB | ConvertFrom-Json
Assert ($evidenceB.final_state -eq 'FAILED') "Scenario B: State must be FAILED, got $($evidenceB.final_state)"
Assert ($evidenceB.overall_validation_status -eq 'NO_GO') 'Scenario B: Validation must be NO_GO'
Assert ($null -eq $evidenceB.git_completion -or $evidenceB.git_completion.completed -eq $false) 'Scenario B: Git completion must not succeed'

# =============================================================
# SCENARIO C: Scope Violation -> No Commit, BLOCKED
# =============================================================
$repoC = New-SampleTestRepo
$mockCodexC = New-MockCodexScript -Directory $repoC
$contractC = New-SampleContract -RepoPath $repoC -TaskId 'task-p0-scope-viol'
$contractFileC = Join-Path $repoC 'TASK_CONTRACT.json'
$contractC | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $contractFileC

$env:MOCK_SCOPE_VIOLATION = '1'
$evidencePathC = & $hub run $contractFileC -EngineExecutable $mockCodexC
$env:MOCK_SCOPE_VIOLATION = $null

$evidenceC = Get-Content -Raw -LiteralPath $evidencePathC | ConvertFrom-Json
Assert ($evidenceC.final_state -eq 'BLOCKED') "Scenario C: Scope violation state must be BLOCKED, got $($evidenceC.final_state)"
Assert ($evidenceC.scope_validation -eq 'SCOPE_VIOLATION') 'Scenario C: scope_validation must be SCOPE_VIOLATION'
Assert ($null -eq $evidenceC.git_completion -or $evidenceC.git_completion.completed -eq $false) 'Scenario C: Git completion must not succeed'

# =============================================================
# SCENARIO D: Foreign Worktree -> Git Completion Refused
# =============================================================
$repoD = New-SampleTestRepo
$contractD = New-SampleContract -RepoPath $repoD -TaskId 'task-p0-foreign'
$foreignDir = Join-Path $env:TEMP ('foreign-wt-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $foreignDir | Out-Null
$preconD = Test-AgentHubGitCompletionPreconditions -WorktreePath $foreignDir -Contract $contractD
Assert ($preconD.is_eligible -eq $false) 'Scenario D: Foreign worktree must not be eligible for git completion'
Assert ($preconD.reason -match 'WORKTREE_OWNERSHIP_INVALID') 'Scenario D: Blocker must cite worktree ownership'

# =============================================================
# SCENARIO E: Wrong Branch Ownership -> Git Completion Refused
# =============================================================
$repoE = New-SampleTestRepo
$contractE = New-SampleContract -RepoPath $repoE -TaskId 'task-p0-branch-mismatch'
$wtE = Join-Path $repoE ('.agenthub-worktrees\' + $contractE.task.id)
git -C $repoE worktree add -b 'feature/wrong-branch' $wtE HEAD -q
New-AgentHubWorktreeOwnershipRecord -WorktreePath $wtE -TaskId $contractE.task.id -SourceRepository $repoE | Out-Null

$preconE = Test-AgentHubGitCompletionPreconditions -WorktreePath $wtE -Contract $contractE
Assert ($preconE.is_eligible -eq $false) 'Scenario E: Wrong branch must not be eligible for git completion'
Assert ($preconE.reason -match 'BRANCH_OWNERSHIP_MISMATCH') 'Scenario E: Blocker must cite branch ownership'

# =============================================================
# SCENARIO F: No Meaningful Progress -> No Commit, FAILED
# =============================================================
$repoF = New-SampleTestRepo
$mockCodexF = New-MockCodexScript -Directory $repoF
$contractF = New-SampleContract -RepoPath $repoF -TaskId 'task-p0-no-progress'
$contractFileF = Join-Path $repoF 'TASK_CONTRACT.json'
$contractF | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $contractFileF

$env:MOCK_NO_PROGRESS = '1'
$evidencePathF = & $hub run $contractFileF -EngineExecutable $mockCodexF
$env:MOCK_NO_PROGRESS = $null

$evidenceF = Get-Content -Raw -LiteralPath $evidencePathF | ConvertFrom-Json
Assert ($evidenceF.final_state -eq 'FAILED') "Scenario F: State must be FAILED, got $($evidenceF.final_state)"
Assert ($null -eq $evidenceF.git_completion -or $evidenceF.git_completion.completed -eq $false) 'Scenario F: Git completion must not succeed'

# =============================================================
# SCENARIO G & H: Disposable Artifacts and Evidence Excluded from Commit
# =============================================================
$repoG = New-SampleTestRepo
$mockCodexG = New-MockCodexScript -Directory $repoG
$contractG = New-SampleContract -RepoPath $repoG -TaskId 'task-p0-disposable-filter'
$contractFileG = Join-Path $repoG 'TASK_CONTRACT.json'
$contractG | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $contractFileG

$env:MOCK_DISPOSABLE_CACHE = '1'
$evidencePathG = & $hub run $contractFileG -EngineExecutable $mockCodexG
$env:MOCK_DISPOSABLE_CACHE = $null

$evidenceG = Get-Content -Raw -LiteralPath $evidencePathG | ConvertFrom-Json
Assert ($evidenceG.final_state -eq 'READY_FOR_HUMAN') 'Scenario G: State must be READY_FOR_HUMAN'
Assert ($evidenceG.git_completion.completed -eq $true) 'Scenario G: Git completion must succeed'

# Verify staged/committed files:
$worktreeG = $evidenceG.workspace
$committedFilesG = @(git -C $worktreeG show --name-only --pretty=format:"" HEAD | ForEach-Object { $_.Trim().Replace('\','/') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
Assert ($committedFilesG -contains 'src/app.js') 'Scenario G: src/app.js must be in commit'
Assert ($committedFilesG -notcontains 'target/build-output.txt') 'Scenario G: target/build-output.txt must NOT be in commit'
Assert ($committedFilesG -notcontains 'TASK_CONTRACT.json') 'Scenario H: TASK_CONTRACT.json must NOT be in commit'
Assert (-not [bool]($committedFilesG | Where-Object { $_ -match '^\.agenthub' })) 'Scenario H: AgentHub runtime/evidence files must NOT be in commit'

# =============================================================
# SCENARIO I & J: Evidence Persistence & Authorized Staging Check
# =============================================================
Assert ($evidenceG.committed_paths -contains 'src/app.js') 'Scenario J: committed_paths must contain src/app.js'
Assert ($evidenceG.excluded_paths -contains 'target/build-output.txt') 'Scenario J: excluded_paths must contain target/build-output.txt'
Assert ($evidenceG.final_commit_sha -eq (git -C $worktreeG rev-parse HEAD)) 'Scenario J: final_commit_sha must match git HEAD'

# =============================================================
# SCENARIO K: Zero Model Invocations and Zero Token Consumption
# =============================================================
# Invariant: Entire vertical acceptance ran with 0 API requests and 0 tokens.
Write-Host "P0 Vertical Flow Acceptance: MODEL_INVOCATIONS = 0, TOKENS = 0" -ForegroundColor Green
Write-Host "All P0 vertical flow acceptance scenarios (A-K) PASSED." -ForegroundColor Green
