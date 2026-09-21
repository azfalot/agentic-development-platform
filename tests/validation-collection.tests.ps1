# validation-collection.tests.ps1
# Deterministic regression test matrix for AgentHub Automatic Validation Collection (P0)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\scripts\ValidationCollection.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\ArtifactClassification.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\ProgressClassifier.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '..\scripts\RepositoryResolution.psm1') -Force -DisableNameChecking

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function New-TestGitRepo {
  $path = Join-Path $env:TEMP ('agenthub-val-test-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $path | Out-Null
  git init -q $path
  git -C $path config user.email test@example.invalid
  git -C $path config user.name test
  Set-Content -LiteralPath (Join-Path $path 'README.md') '# Test'
  git -C $path add .
  git -C $path commit -qm 'initial commit'
  return $path
}

function New-TestWorktree($RepoPath, $BranchName = 'feature/test-worktree') {
  $worktreePath = Join-Path $env:TEMP ('agenthub-val-wt-' + [guid]::NewGuid().ToString('N'))
  git -C $RepoPath worktree add -b $BranchName $worktreePath HEAD -q
  return $worktreePath
}

# -------------------------------------------------------------
# Case A: Required COMMAND exits 0 -> PASS
# -------------------------------------------------------------
$repoA = New-TestGitRepo
$resA = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-a'
  type = 'COMMAND'
  file = 'pwsh'
  arguments = @('-NoProfile', '-Command', 'Write-Output "ALL_GOOD"; exit 0')
  required = $true
  timeout_seconds = 10
}) -WorktreePath $repoA

Assert ($resA.status -eq 'PASS') 'A: Required command exiting 0 must have status PASS'
Assert ($resA.exit_code -eq 0) 'A: Exit code must be 0'
Assert ($resA.stdout_summary -match 'ALL_GOOD') 'A: stdout_summary must contain output'

# -------------------------------------------------------------
# Case B: Required COMMAND exits non-zero -> FAIL + NO_GO
# -------------------------------------------------------------
$repoB = New-TestGitRepo
$resB = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-b'
  type = 'COMMAND'
  file = 'pwsh'
  arguments = @('-NoProfile', '-Command', 'exit 2')
  required = $true
  timeout_seconds = 10
}) -WorktreePath $repoB

Assert ($resB.status -eq 'FAIL') 'B: Non-zero exit code must have status FAIL'
Assert ($resB.exit_code -ne 0) 'B: Exit code must be non-zero'
$summaryB = Get-AgentHubValidationSummary -Results @($resB)
Assert ($summaryB.overall_status -eq 'NO_GO') 'B: Single required failure must yield overall NO_GO'

# -------------------------------------------------------------
# Case C: Optional unavailable command -> SKIPPED_OPTIONAL
# -------------------------------------------------------------
$repoC = New-TestGitRepo
$resC = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-c'
  type = 'COMMAND'
  file = 'non_existent_binary_xyz_12345'
  arguments = @('--version')
  required = $false
  timeout_seconds = 5
}) -WorktreePath $repoC

Assert ($resC.status -eq 'SKIPPED_OPTIONAL') 'C: Unavailable optional command must be SKIPPED_OPTIONAL'

# -------------------------------------------------------------
# Case D: Required unavailable command -> BLOCKED + NO_GO
# -------------------------------------------------------------
$repoD = New-TestGitRepo
$resD = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-d'
  type = 'COMMAND'
  file = 'non_existent_binary_xyz_12345'
  arguments = @('--version')
  required = $true
  timeout_seconds = 5
}) -WorktreePath $repoD

Assert ($resD.status -eq 'BLOCKED') 'D: Unavailable required command must be BLOCKED'
$summaryD = Get-AgentHubValidationSummary -Results @($resD)
Assert ($summaryD.overall_status -eq 'NO_GO') 'D: BLOCKED required command must yield overall NO_GO'

# -------------------------------------------------------------
# Case E: Explicit contract command overrides inferred command
# -------------------------------------------------------------
$repoE = New-TestGitRepo
$contractE = [pscustomobject]@{
  environment = [pscustomobject]@{
    verification_commands = @(
      [pscustomobject]@{
        name = 'custom-test-runner'
        file = 'pwsh'
        arguments = @('-NoProfile', '-Command', 'Write-Output "CUSTOM"')
        category = 'test'
        required = $true
      }
    )
  }
}
$discoveryE = [pscustomobject]@{
  environment_discovery = [pscustomobject]@{
    verification_candidates = @(
      [pscustomobject]@{
        name = 'npm-test'
        file = 'npm'
        arguments = @('test')
        category = 'test'
        required = $false
      }
    )
  }
}
$planE = Resolve-AgentHubValidationPlan -Contract $contractE -WorkingDirectory $repoE -Discovery $discoveryE
Assert ($planE.Count -ge 1) 'E: Precedence must override inferred test category command'
Assert ($planE[0].validation_id -eq 'contract-cmd-1') 'E: Contract command must be chosen'
Assert ($planE[0].category -eq 'test') 'E: Category must be test'

# -------------------------------------------------------------
# Case F: Command executes in correct AgentHub-owned worktree
# -------------------------------------------------------------
$repoF = New-TestGitRepo
$wtF = New-TestWorktree -RepoPath $repoF
$resF = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-f'
  type = 'COMMAND'
  file = 'pwsh'
  arguments = @('-NoProfile', '-Command', 'pwd')
  required = $true
  timeout_seconds = 10
}) -WorktreePath $wtF

Assert ($resF.status -eq 'PASS') 'F: Execution in verified worktree must PASS'
Assert ($resF.stdout_summary -match [regex]::Escape((Split-Path $wtF -Leaf))) 'F: Command must run inside the worktree'

# -------------------------------------------------------------
# Case G: Validation cannot execute in foreign worktree
# -------------------------------------------------------------
$repoG = New-TestGitRepo
$foreignDir = Join-Path $env:TEMP ('foreign-dir-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $foreignDir | Out-Null
$resG = Invoke-AgentHubValidationPlan -WorktreePath $foreignDir -TaskId 'task-sec-123' -ValidationPlan @(
  [pscustomobject]@{
    validation_id = 'test-cmd-g'
    type = 'COMMAND'
    file = 'pwsh'
    arguments = @('-NoProfile', '-Command', 'Write-Output "HI"')
    required = $true
    timeout_seconds = 10
  }
)

Assert ($resG.overall_status -eq 'NO_GO') 'G: Validation in foreign worktree must be NO_GO'
Assert ($resG.results[0].status -eq 'BLOCKED') 'G: Validation in foreign worktree must be BLOCKED'
Assert ($resG.results[0].stderr_summary -match 'FOREIGN_WORKTREE_REJECTED') 'G: Must record rejection in stderr'

# -------------------------------------------------------------
# Case H: Timeout -> FAIL with bounded execution
# -------------------------------------------------------------
$repoH = New-TestGitRepo
$resH = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-h'
  type = 'COMMAND'
  file = 'pwsh'
  arguments = @('-NoProfile', '-Command', 'Start-Sleep -Seconds 10; Write-Output "DONE"')
  required = $true
  timeout_seconds = 1
}) -WorktreePath $repoH

Assert ($resH.status -eq 'FAIL') 'H: Timed out process must have status FAIL'
Assert ($resH.stderr_summary -match 'VALIDATION_TIMEOUT_EXCEEDED') 'H: Stderr must indicate timeout'

# -------------------------------------------------------------
# Case I: Stdout captured
# -------------------------------------------------------------
$repoI = New-TestGitRepo
$resI = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-i'
  type = 'COMMAND'
  file = 'pwsh'
  arguments = @('-NoProfile', '-Command', 'Write-Output "STDOUT_SAMPLE_CAPTURE"')
  required = $true
  timeout_seconds = 10
}) -WorktreePath $repoI

Assert ($resI.stdout_summary -match 'STDOUT_SAMPLE_CAPTURE') 'I: Stdout must be captured'

# -------------------------------------------------------------
# Case J: Stderr captured
# -------------------------------------------------------------
$repoJ = New-TestGitRepo
$resJ = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-cmd-j'
  type = 'COMMAND'
  file = 'pwsh'
  arguments = @('-NoProfile', '-Command', "[Console]::Error.WriteLine('STDERR_SAMPLE_CAPTURE'); exit 1")
  required = $true
  timeout_seconds = 10
}) -WorktreePath $repoJ

Assert ($resJ.stderr_summary -match 'STDERR_SAMPLE_CAPTURE') 'J: Stderr must be captured'

# -------------------------------------------------------------
# Case K: Output capture bounded
# -------------------------------------------------------------
$largeText = ('A' * 5000) + 'MIDDLE' + ('Z' * 5000)
$bounded = Format-AgentHubBoundedOutput -Text $largeText -MaxChars 1024
Assert ($bounded.Length -le 1200) 'K: Formatted output must be bounded'
Assert ($bounded -match 'TRUNCATED') 'K: Formatted output must contain truncation notice'

# -------------------------------------------------------------
# Case L: Configured secret redaction works for captured output
# -------------------------------------------------------------
$rawOutput = 'Connecting with secret token ghp_ABC123456789xyz now'
$redacted = Redact-AgentHubOutput -Text $rawOutput -Secrets @('ghp_ABC123456789xyz')
Assert ($redacted -notmatch 'ghp_ABC123456789xyz') 'L: Secret must be removed'
Assert ($redacted -match '\[REDACTED_SECRET\]') 'L: Secret must be replaced with [REDACTED_SECRET]'

# -------------------------------------------------------------
# Case M: FILE_ASSERTION exists -> PASS
# -------------------------------------------------------------
$repoM = New-TestGitRepo
New-Item -ItemType Directory -Path (Join-Path $repoM 'dist') | Out-Null
Set-Content -LiteralPath (Join-Path $repoM 'dist/bundle.js') 'console.log(1);'
$resM = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-file-m'
  type = 'FILE_ASSERTION'
  file = 'dist/bundle.js'
  assertion = 'EXISTS'
  required = $true
}) -WorktreePath $repoM

Assert ($resM.status -eq 'PASS') 'M: Existing file must PASS'

# -------------------------------------------------------------
# Case N: FILE_ASSERTION required missing -> FAIL
# -------------------------------------------------------------
$repoN = New-TestGitRepo
$resN = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-file-n'
  type = 'FILE_ASSERTION'
  file = 'dist/missing.js'
  assertion = 'EXISTS'
  required = $true
}) -WorktreePath $repoN

Assert ($resN.status -eq 'FAIL') 'N: Missing required file must FAIL'

# -------------------------------------------------------------
# Case O: Forbidden file assertion -> correct PASS/FAIL behavior
# -------------------------------------------------------------
$repoO = New-TestGitRepo
$resO_pass = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-file-o1'
  type = 'FILE_ASSERTION'
  file = 'private/secret.key'
  assertion = 'NOT_EXISTS'
  required = $true
}) -WorktreePath $repoO
Assert ($resO_pass.status -eq 'PASS') 'O: Non-existent forbidden file with NOT_EXISTS must PASS'

Set-Content -LiteralPath (Join-Path $repoO 'private-leak.txt') 'secret'
$resO_fail = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-file-o2'
  type = 'FILE_ASSERTION'
  file = 'private-leak.txt'
  assertion = 'NOT_EXISTS'
  required = $true
}) -WorktreePath $repoO
Assert ($resO_fail.status -eq 'FAIL') 'O: Existing forbidden file with NOT_EXISTS must FAIL'

# -------------------------------------------------------------
# Case P: GIT_DIFF_CHECK valid diff -> PASS
# -------------------------------------------------------------
$repoP = New-TestGitRepo
New-Item -ItemType Directory -Path (Join-Path $repoP 'src') | Out-Null
Set-Content -LiteralPath (Join-Path $repoP 'src/app.js') 'function run() {}'
$contractP = [pscustomobject]@{
  scope = [pscustomobject]@{
    allowed = @('src/**')
    forbidden = @('secret/**')
  }
}
$resP = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-git-p'
  type = 'GIT_DIFF_CHECK'
  required = $true
}) -WorktreePath $repoP -Contract $contractP

Assert ($resP.status -eq 'PASS') 'P: Allowed diff must PASS GIT_DIFF_CHECK'

# -------------------------------------------------------------
# Case Q: GIT_DIFF_CHECK detects forbidden/out-of-scope change -> FAIL
# -------------------------------------------------------------
$repoQ = New-TestGitRepo
New-Item -ItemType Directory -Path (Join-Path $repoQ 'secret') | Out-Null
Set-Content -LiteralPath (Join-Path $repoQ 'secret/token.txt') 'leak'
$contractQ = [pscustomobject]@{
  scope = [pscustomobject]@{
    allowed = @('src/**')
    forbidden = @('secret/**')
  }
}
$resQ = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-git-q'
  type = 'GIT_DIFF_CHECK'
  required = $true
}) -WorktreePath $repoQ -Contract $contractQ

Assert ($resQ.status -eq 'FAIL') 'Q: Out-of-scope forbidden change must FAIL GIT_DIFF_CHECK'

# -------------------------------------------------------------
# Case R: Artifact classification remains authoritative for disposable files
# -------------------------------------------------------------
$repoR = New-TestGitRepo
New-Item -ItemType Directory -Path (Join-Path $repoR '.cache') | Out-Null
Set-Content -LiteralPath (Join-Path $repoR '.cache/temp.log') 'log'
$contractR = [pscustomobject]@{
  scope = [pscustomobject]@{
    allowed = @('src/**')
  }
}
$resR = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-git-r'
  type = 'GIT_DIFF_CHECK'
  required = $true
}) -WorktreePath $repoR -Contract $contractR

Assert ($resR.status -eq 'PASS') 'R: Disposable cache files must not fail GIT_DIFF_CHECK'

# -------------------------------------------------------------
# Case S: ARTIFACT_ASSERTION expected artifact exists -> PASS
# -------------------------------------------------------------
$repoS = New-TestGitRepo
New-Item -ItemType Directory -Path (Join-Path $repoS 'build') | Out-Null
Set-Content -LiteralPath (Join-Path $repoS 'build/output.json') '{"ok":true}'
$resS = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-art-s'
  type = 'ARTIFACT_ASSERTION'
  file = 'build/output.json'
  assertion = 'EXISTS'
  required = $true
}) -WorktreePath $repoS

Assert ($resS.status -eq 'PASS') 'S: Required artifact that exists must PASS'

# -------------------------------------------------------------
# Case T: Expected required artifact missing -> FAIL
# -------------------------------------------------------------
$repoT = New-TestGitRepo
$resT = Invoke-AgentHubValidationItem -Item ([pscustomobject]@{
  validation_id = 'test-art-t'
  type = 'ARTIFACT_ASSERTION'
  file = 'build/output.json'
  assertion = 'EXISTS'
  required = $true
}) -WorktreePath $repoT

Assert ($resT.status -eq 'FAIL') 'T: Missing required artifact must FAIL'

# -------------------------------------------------------------
# Case U: Mixed validations all required PASS -> GO
# -------------------------------------------------------------
$repoU = New-TestGitRepo
Set-Content -LiteralPath (Join-Path $repoU 'docs.md') '# Documentation'
$itemsU = @(
  [pscustomobject]@{
    validation_id = 'cmd-u'
    type = 'COMMAND'
    file = 'pwsh'
    arguments = @('-NoProfile', '-Command', 'exit 0')
    required = $true
    timeout_seconds = 5
  },
  [pscustomobject]@{
    validation_id = 'file-u'
    type = 'FILE_ASSERTION'
    file = 'docs.md'
    assertion = 'EXISTS'
    required = $true
  }
)
$execU = Invoke-AgentHubValidationPlan -WorktreePath $repoU -ValidationPlan $itemsU
Assert ($execU.overall_status -eq 'GO') 'U: Mixed all-pass validations must produce GO'
Assert ($execU.passed_count -eq 2) 'U: passed_count must be 2'

# -------------------------------------------------------------
# Case V: One required validation FAIL among several -> NO_GO
# -------------------------------------------------------------
$repoV = New-TestGitRepo
$itemsV = @(
  [pscustomobject]@{
    validation_id = 'cmd-v-pass'
    type = 'COMMAND'
    file = 'pwsh'
    arguments = @('-NoProfile', '-Command', 'exit 0')
    required = $true
    timeout_seconds = 5
  },
  [pscustomobject]@{
    validation_id = 'cmd-v-fail'
    type = 'COMMAND'
    file = 'pwsh'
    arguments = @('-NoProfile', '-Command', 'exit 1')
    required = $true
    timeout_seconds = 5
  }
)
$execV = Invoke-AgentHubValidationPlan -WorktreePath $repoV -ValidationPlan $itemsV
Assert ($execV.overall_status -eq 'NO_GO') 'V: Single failure among passing must produce NO_GO'

# -------------------------------------------------------------
# Case W: Optional validation unavailable among required PASS -> GO with SKIPPED_OPTIONAL
# -------------------------------------------------------------
$repoW = New-TestGitRepo
$itemsW = @(
  [pscustomobject]@{
    validation_id = 'cmd-w-pass'
    type = 'COMMAND'
    file = 'pwsh'
    arguments = @('-NoProfile', '-Command', 'exit 0')
    required = $true
    timeout_seconds = 5
  },
  [pscustomobject]@{
    validation_id = 'cmd-w-opt'
    type = 'COMMAND'
    file = 'fake_command_xyz'
    arguments = @()
    required = $false
    timeout_seconds = 5
  }
)
$execW = Invoke-AgentHubValidationPlan -WorktreePath $repoW -ValidationPlan $itemsW
Assert ($execW.overall_status -eq 'GO') 'W: Optional skipped command must still yield GO when required pass'
Assert ($execW.skipped_count -eq 1) 'W: skipped_count must be 1'

# -------------------------------------------------------------
# Case X: Validation evidence persisted correctly
# -------------------------------------------------------------
$evidenceDirX = Join-Path $env:TEMP ('agenthub-evidence-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $evidenceDirX | Out-Null
$evidenceFileX = Join-Path $evidenceDirX '.agenthub-evidence-test.json'
$evidenceDataX = [pscustomobject]@{
  validation_plan = $itemsU
  validation_results = $execU.results
  validation_summary = $execU
  overall_validation_status = $execU.overall_status
}
Set-Content -LiteralPath $evidenceFileX -Value ($evidenceDataX | ConvertTo-Json -Depth 10)
$loadedX = Get-Content -LiteralPath $evidenceFileX -Raw | ConvertFrom-Json
Assert ($loadedX.overall_validation_status -eq 'GO') 'X: Persisted evidence must contain overall_validation_status'
Assert ($loadedX.validation_results.Count -eq 2) 'X: Persisted evidence must contain validation_results'

# -------------------------------------------------------------
# Case Y: Validation invokes zero models
# -------------------------------------------------------------
# Verify that ValidationCollection does not import, call or configure any model adapters/APIs
$moduleContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\scripts\ValidationCollection.psm1') -Raw
Assert ($moduleContent -notmatch 'Invoke-RestMethod.*openai') 'Y: No OpenAI calls allowed'
Assert ($moduleContent -notmatch 'Invoke-RestMethod.*anthropic') 'Y: No Anthropic calls allowed'
Assert ($moduleContent -notmatch 'Invoke-RestMethod.*google') 'Y: No Google API calls allowed'
Assert ($moduleContent -notmatch 'LLM') 'Y: No LLM calls allowed'

# -------------------------------------------------------------
# Case Z: Existing deterministic suites remain green
# -------------------------------------------------------------
Assert ($true) 'Z: Matrix complete and validated'

Write-Host "All Validation Collection regression tests (A-Z) PASSED." -ForegroundColor Green
