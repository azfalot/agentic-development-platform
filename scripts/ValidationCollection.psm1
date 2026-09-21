# ValidationCollection.psm1
# Deterministic Automatic Validation and Machine-Readable Evidence Collection for AgentHub

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ArtifactClassification.psm1') -Global -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'ProgressClassifier.psm1') -Global -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'RepositoryResolution.psm1') -Global -Force -DisableNameChecking

function Redact-AgentHubOutput {
  param(
    [string]$Text,
    [string[]]$Secrets = @()
  )
  if ([string]::IsNullOrEmpty($Text)) { return '' }
  $redacted = $Text

  $allSecrets = [System.Collections.Generic.List[string]]::new()
  if ($Secrets) {
    foreach ($s in $Secrets) {
      if (-not [string]::IsNullOrWhiteSpace($s) -and $s.Length -ge 3) {
        $allSecrets.Add($s)
      }
    }
  }

  # Inspect well-known environment secret names
  foreach ($envVar in @('AGENTHUB_SECRET', 'AGENTHUB_TOKEN', 'GITHUB_TOKEN', 'AGENT_API_KEY', 'TEST_SECRET_KEY')) {
    $val = [Environment]::GetEnvironmentVariable($envVar)
    if (-not [string]::IsNullOrWhiteSpace($val) -and $val.Length -ge 4) {
      $allSecrets.Add($val)
    }
  }

  foreach ($secret in $allSecrets) {
    if (-not [string]::IsNullOrEmpty($secret)) {
      $redacted = $redacted.Replace($secret, '[REDACTED_SECRET]')
    }
  }
  return $redacted
}

function Format-AgentHubBoundedOutput {
  param(
    [string]$Text,
    [int]$MaxChars = 4096,
    [string[]]$Secrets = @()
  )
  if ([string]::IsNullOrEmpty($Text)) { return '' }
  $clean = Redact-AgentHubOutput -Text $Text -Secrets $Secrets
  if ($clean.Length -le $MaxChars) {
    return $clean
  }
  $half = [math]::Floor(($MaxChars - 64) / 2)
  $head = $clean.Substring(0, $half)
  $tail = $clean.Substring($clean.Length - $half)
  $omitted = $clean.Length - ($half * 2)
  return "$head`r`n... [TRUNCATED $omitted BYTES] ...`r`n$tail"
}

function Resolve-AgentHubValidationPlan {
  param(
    $Contract,
    [string]$WorkingDirectory = '',
    $Discovery = $null,
    $ProjectConfig = $null
  )
  $plan = [System.Collections.Generic.List[PSCustomObject]]::new()
  $definedCategories = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  # 1. Precedence 1: Explicit Task Contract verification
  if ($null -ne $Contract) {
    # 1a. Explicit environment verification_commands
    if ($Contract.environment -and $Contract.environment.verification_commands) {
      $idx = 1
      foreach ($vc in @($Contract.environment.verification_commands)) {
        $name = if ($vc.name) { $vc.name } else { "contract-cmd-$idx" }
        $category = if ($vc.category) { $vc.category } else { $name }
        $required = if ($null -ne $vc.required) { [bool]$vc.required } else { $true }
        $args = if ($vc.arguments) { @($vc.arguments) } else { @() }
        $timeout = if ($vc.timeout_seconds) { [int]$vc.timeout_seconds } else { 60 }
        $workdir = if ($vc.working_directory) { $vc.working_directory } else { '' }

        $plan.Add([pscustomobject]@{
          validation_id         = "contract-cmd-$idx"
          type                  = 'COMMAND'
          source                = 'task_contract'
          category              = $category
          required              = $required
          file                  = $vc.file
          arguments             = $args
          command_or_assertion  = "$($vc.file) $($args -join ' ')".Trim()
          timeout_seconds       = $timeout
          working_directory     = $workdir
        })
        $definedCategories.Add($category) | Out-Null
        $idx++
      }
    }

    # 1b. Explicit contract assertions (if defined)
    if ($Contract.assertions) {
      $aIdx = 1
      foreach ($a in @($Contract.assertions)) {
        $aType = if ($a.type) { $a.type } else { 'FILE_ASSERTION' }
        $aReq = if ($null -ne $a.required) { [bool]$a.required } else { $true }
        $plan.Add([pscustomobject]@{
          validation_id         = "contract-assert-$aIdx"
          type                  = $aType
          source                = 'task_contract'
          category              = if ($a.category) { $a.category } else { 'assertion' }
          required              = $aReq
          file_path             = $a.file_path
          artifact_path         = $a.artifact_path
          assertion             = if ($a.assertion) { $a.assertion } else { 'EXISTS' }
          min_size_bytes        = if ($a.min_size_bytes) { [int]$a.min_size_bytes } else { 0 }
          command_or_assertion  = if ($a.file_path) { "$($a.assertion): $($a.file_path)" } else { "$($a.assertion): $($a.artifact_path)" }
        })
        $aIdx++
      }
    }
  }

  # 2. Precedence 2: Explicit project configuration (.agenthub-verification.json)
  $cfg = $ProjectConfig
  if ($null -eq $cfg -and -not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $cfgPath = Join-Path $WorkingDirectory '.agenthub-verification.json'
    if (Test-Path -LiteralPath $cfgPath) {
      try { $cfg = Get-Content -Raw $cfgPath | ConvertFrom-Json } catch {}
    }
  }

  if ($null -ne $cfg) {
    if ($cfg.commands) {
      $cIdx = 1
      foreach ($cmd in @($cfg.commands)) {
        $category = if ($cmd.category) { $cmd.category } else { "project-cmd-$cIdx" }
        if (-not $definedCategories.Contains($category)) {
          $required = if ($null -ne $cmd.required) { [bool]$cmd.required } else { $true }
          $args = if ($cmd.arguments) { @($cmd.arguments) } else { @() }
          $timeout = if ($cmd.timeout_seconds) { [int]$cmd.timeout_seconds } else { 60 }
          $workdir = if ($cmd.working_directory) { $cmd.working_directory } else { '' }

          $plan.Add([pscustomobject]@{
            validation_id         = "project-cmd-$cIdx"
            type                  = 'COMMAND'
            source                = 'project_config'
            category              = $category
            required              = $required
            file                  = $cmd.file
            arguments             = $args
            command_or_assertion  = "$($cmd.file) $($args -join ' ')".Trim()
            timeout_seconds       = $timeout
            working_directory     = $workdir
          })
          $definedCategories.Add($category) | Out-Null
          $cIdx++
        }
      }
    }
    if ($cfg.assertions) {
      $caIdx = 1
      foreach ($a in @($cfg.assertions)) {
        $aType = if ($a.type) { $a.type } else { 'FILE_ASSERTION' }
        $aReq = if ($null -ne $a.required) { [bool]$a.required } else { $true }
        $plan.Add([pscustomobject]@{
          validation_id         = "project-assert-$caIdx"
          type                  = $aType
          source                = 'project_config'
          category              = if ($a.category) { $a.category } else { 'assertion' }
          required              = $aReq
          file_path             = $a.file_path
          artifact_path         = $a.artifact_path
          assertion             = if ($a.assertion) { $a.assertion } else { 'EXISTS' }
          min_size_bytes        = if ($a.min_size_bytes) { [int]$a.min_size_bytes } else { 0 }
          command_or_assertion  = if ($a.file_path) { "$($a.assertion): $($a.file_path)" } else { "$($a.assertion): $($a.artifact_path)" }
        })
        $caIdx++
      }
    }
  }

  # 3. Precedence 3: Safely inferred verification capabilities from ProjectEnvironmentDiscovery
  if ($null -ne $Discovery -and $Discovery.verification_tools) {
    # Check Playwright if e2e is requested and not already defined
    if ($Contract -and $Contract.verification -and $Contract.verification.e2e -and $Contract.verification.e2e -ne 'NOT_APPLICABLE') {
      if (-not $definedCategories.Contains('playwright') -and -not $definedCategories.Contains('e2e')) {
        if ($Discovery.verification_tools.playwright -and $Discovery.verification_tools.playwright.declared) {
          $plan.Add([pscustomobject]@{
            validation_id         = 'inferred-e2e-playwright'
            type                  = 'COMMAND'
            source                = 'environment_discovery'
            category              = 'e2e'
            required              = ($Contract.verification.e2e -eq 'NOT_RUN' -or $Contract.verification.e2e -eq 'PASSED')
            file                  = 'npx'
            arguments             = @('playwright', 'test')
            command_or_assertion  = 'npx playwright test'
            timeout_seconds       = 120
            working_directory     = if ($Discovery.verification_tools.playwright.source) { [IO.Path]::GetDirectoryName($Discovery.verification_tools.playwright.source) } else { '' }
          })
          $definedCategories.Add('e2e') | Out-Null
        }
      }
    }
  }

  # 4. Standard Inherent Checks (GIT_DIFF_CHECK for scope)
  $plan.Add([pscustomobject]@{
    validation_id         = 'inherent-scope-validity'
    type                  = 'GIT_DIFF_CHECK'
    source                = 'task_contract'
    category              = 'scope'
    required              = $true
    assertion             = 'SCOPE_VALID'
    command_or_assertion  = 'GIT_DIFF_CHECK: SCOPE_VALID'
  })

  return @($plan)
}

function Invoke-AgentHubValidationItem {
  param(
    [pscustomobject]$Item,
    [string]$WorktreePath,
    $Contract = $null,
    [string[]]$Secrets = @(),
    [int]$DefaultTimeoutSeconds = 60
  )
  $startedAt = (Get-Date)
  $evidencePaths = [System.Collections.Generic.List[string]]::new()
  $status = 'UNKNOWN'
  $exitCode = $null
  $stdoutSummary = ''
  $stderrSummary = ''
  $resolvedWorkDir = $WorktreePath

  if (-not [string]::IsNullOrWhiteSpace($Item.working_directory)) {
    $candidate = Join-Path $WorktreePath $Item.working_directory
    if (Test-Path -LiteralPath $candidate) {
      $resolvedWorkDir = (Resolve-Path $candidate).Path
    }
  }

  switch ($Item.type) {
    'COMMAND' {
      $file = $Item.file
      if ([string]::IsNullOrWhiteSpace($file)) {
        $status = if ($Item.required) { 'BLOCKED' } else { 'SKIPPED_OPTIONAL' }
        $stderrSummary = 'Validation command executable is empty'
        break
      }

      # Test if executable is resolvable
      $cmdInfo = Get-Command $file -ErrorAction SilentlyContinue
      $directPath = if (-not [IO.Path]::IsPathRooted($file)) { Join-Path $resolvedWorkDir $file } else { $file }
      $isDirectExecutable = Test-Path -LiteralPath $directPath

      if (-not $cmdInfo -and -not $isDirectExecutable) {
        if ($Item.required) {
          $status = 'BLOCKED'
          $stderrSummary = "Executable not found: $file"
        } else {
          $status = 'SKIPPED_OPTIONAL'
          $stderrSummary = "Optional executable not found: $file"
        }
        break
      }

      $cat = if ($Item.category) { $Item.category } else { 'cmd' }
      $valId = if ($Item.validation_id) { $Item.validation_id } else { [guid]::NewGuid().ToString('N') }
      $outLog = Join-Path $WorktreePath ".agenthub-verify-$cat-$valId.out.log"
      $errLog = Join-Path $WorktreePath ".agenthub-verify-$cat-$valId.err.log"
      $evidencePaths.Add($outLog)
      $evidencePaths.Add($errLog)

      $args = if ($Item.arguments) { @($Item.arguments) } else { @() }
      $timeoutSeconds = if ($Item.timeout_seconds) { [int]$Item.timeout_seconds } else { $DefaultTimeoutSeconds }
      $timeoutMs = [int]($timeoutSeconds * 1000)

      $execTarget = if ($isDirectExecutable) { $directPath } else { $file }
      try {
        $proc = Start-Process `
          -FilePath $execTarget `
          -ArgumentList $args `
          -WorkingDirectory $resolvedWorkDir `
          -RedirectStandardOutput $outLog `
          -RedirectStandardError $errLog `
          -PassThru

        $completedInTime = $proc.WaitForExit($timeoutMs)
        if (-not $completedInTime) {
          try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
          $status = if ($Item.required) { 'FAIL' } else { 'SKIPPED_OPTIONAL' }
          $exitCode = -1
          $stderrSummary = "VALIDATION_TIMEOUT_EXCEEDED: Process exceeded timeout of $($timeoutSeconds)s"
        } else {
          $exitCode = $proc.ExitCode
          $status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
        }
      } catch {
        $status = if ($Item.required) { 'FAIL' } else { 'SKIPPED_OPTIONAL' }
        $exitCode = -1
        $stderrSummary = "EXECUTION_ERROR: $($_.Exception.Message)"
      }

      # Capture stdout / stderr bounded
      if (Test-Path -LiteralPath $outLog) {
        $rawOut = Get-Content -Raw -LiteralPath $outLog -ErrorAction SilentlyContinue
        $stdoutSummary = Format-AgentHubBoundedOutput -Text $rawOut -MaxChars 4096 -Secrets $Secrets
      }
      if (Test-Path -LiteralPath $errLog) {
        $rawErr = Get-Content -Raw -LiteralPath $errLog -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($rawErr)) {
          $stderrSummary = Format-AgentHubBoundedOutput -Text $rawErr -MaxChars 4096 -Secrets $Secrets
        }
      }
    }

    'FILE_ASSERTION' {
      $relPath = if (-not [string]::IsNullOrWhiteSpace($Item.file_path)) { $Item.file_path } else { $Item.file }
      if ([string]::IsNullOrWhiteSpace($relPath)) {
        $status = 'FAIL'
        $stderrSummary = 'FILE_ASSERTION file_path is empty'
        break
      }
      $target = Join-Path $WorktreePath $relPath
      $exists = Test-Path -LiteralPath $target
      $assertion = if ($Item.assertion) { $Item.assertion.ToUpperInvariant() } else { 'EXISTS' }

      if ($assertion -in @('EXISTS', 'PRESENT')) {
        if ($exists) {
          $status = 'PASS'
          $stdoutSummary = "File assertion passed: $relPath exists"
          $evidencePaths.Add($target)
        } else {
          $status = 'FAIL'
          $stderrSummary = "Required file not found: $relPath"
        }
      } elseif ($assertion -in @('FORBIDDEN', 'DOES_NOT_EXIST', 'ABSENT', 'NOT_EXISTS')) {
        if (-not $exists) {
          $status = 'PASS'
          $stdoutSummary = "Forbidden file assertion passed: $relPath is absent"
        } else {
          $status = 'FAIL'
          $stderrSummary = "Forbidden file detected: $relPath"
          $evidencePaths.Add($target)
        }
      } else {
        $status = 'FAIL'
        $stderrSummary = "Unknown FILE_ASSERTION type: $assertion"
      }
    }

    'GIT_DIFF_CHECK' {
      $assertion = if ($Item.assertion) { $Item.assertion.ToUpperInvariant() } else { 'SCOPE_VALID' }
      if ($assertion -eq 'NON_EMPTY') {
        $porcelain = git -C $WorktreePath status --porcelain 2>&1
        $changes = @($porcelain | Where-Object { $_ -notmatch '^\?\?\s+\.agenthub' -and $_ -notmatch '^\?\?\s+TASK_CONTRACT\.json' })
        if ($changes.Count -gt 0) {
          $status = 'PASS'
          $stdoutSummary = "Git diff non-empty check passed: $($changes.Count) files modified"
        } else {
          $status = 'FAIL'
          $stderrSummary = 'Implementation progress required but git diff is empty'
        }
      } elseif ($assertion -eq 'NO_WHITESPACE_ERRORS') {
        $diffCheck = git -C $WorktreePath diff --check 2>&1
        if ($LASTEXITCODE -eq 0) {
          $status = 'PASS'
          $stdoutSummary = 'Git diff whitespace check passed cleanly'
        } else {
          $status = 'FAIL'
          $stderrSummary = "Git diff whitespace check failed:`r`n$($diffCheck | Out-String)"
        }
      } elseif ($assertion -eq 'SCOPE_VALID') {
        $rawStatus = @(git -C $WorktreePath status --porcelain 2>&1 | ForEach-Object { $_.Substring(3).Replace('\','/') } | Where-Object { -not ($_.StartsWith('.agenthub') -or $_ -eq 'TASK_CONTRACT.json') })
        $classification = Get-AgentHubChangeClassification -ChangedFiles $rawStatus -Contract $Contract -RepositoryPath $WorktreePath
        if ($classification.scope_valid) {
          $status = 'PASS'
          $stdoutSummary = "Scope validity check passed: $($classification.implementation_files.Count) product files, $($classification.test_files.Count) test files"
        } else {
          $status = 'FAIL'
          $stderrSummary = "Scope violation: out-of-scope files detected: $($classification.invalid_files -join ', ')"
        }
      } else {
        $status = 'FAIL'
        $stderrSummary = "Unknown GIT_DIFF_CHECK assertion: $assertion"
      }
    }

    'ARTIFACT_ASSERTION' {
      $relPath = if (-not [string]::IsNullOrWhiteSpace($Item.artifact_path)) { $Item.artifact_path } else { $Item.file }
      if ([string]::IsNullOrWhiteSpace($relPath)) {
        $status = 'FAIL'
        $stderrSummary = 'ARTIFACT_ASSERTION artifact_path is empty'
        break
      }
      $target = Join-Path $WorktreePath $relPath
      if (Test-Path -LiteralPath $target) {
        $fileItem = Get-Item -LiteralPath $target
        $minSize = if ($Item.min_size_bytes) { [int]$Item.min_size_bytes } else { 1 }
        if ($fileItem.Length -ge $minSize) {
          $status = 'PASS'
          $stdoutSummary = "Artifact assertion passed: $relPath exists ($($fileItem.Length) bytes)"
          $evidencePaths.Add($target)
        } else {
          $status = 'FAIL'
          $stderrSummary = "Artifact file $relPath below minimum size ($($fileItem.Length) < $minSize bytes)"
        }
      } else {
        $status = 'FAIL'
        $stderrSummary = "Required validation artifact missing: $relPath"
      }
    }

    default {
      $status = 'FAIL'
      $stderrSummary = "Unknown validation type: $($Item.type)"
    }
  }

  $finishedAt = (Get-Date)
  $durationMs = [int]($finishedAt - $startedAt).TotalMilliseconds

  [pscustomobject]@{
    validation_id         = $Item.validation_id
    type                  = $Item.type
    source                = $Item.source
    required              = [bool]$Item.required
    command_or_assertion  = $Item.command_or_assertion
    working_directory     = $resolvedWorkDir
    started_at            = $startedAt.ToUniversalTime().ToString('o')
    finished_at           = $finishedAt.ToUniversalTime().ToString('o')
    duration_ms           = $durationMs
    exit_code             = $exitCode
    status                = $status
    stdout_summary        = $stdoutSummary
    stderr_summary        = $stderrSummary
    evidence_paths        = @($evidencePaths)
  }
}

function Get-AgentHubValidationSummary {
  param(
    [pscustomobject[]]$Results = @()
  )
  $resultsList = @($Results)
  $passedCount = @($resultsList | Where-Object { $_.status -eq 'PASS' }).Count
  $failedCount = @($resultsList | Where-Object { $_.status -eq 'FAIL' }).Count
  $blockedCount = @($resultsList | Where-Object { $_.status -eq 'BLOCKED' }).Count
  $skippedCount = @($resultsList | Where-Object { $_.status -eq 'SKIPPED_OPTIONAL' }).Count

  $requiredFailed = @($resultsList | Where-Object { $_.required -eq $true -and ($_.status -eq 'FAIL' -or $_.status -eq 'BLOCKED') })

  $overallStatus = if ($requiredFailed.Count -gt 0) { 'NO_GO' } else { 'GO' }

  [pscustomobject]@{
    overall_status  = $overallStatus
    go_decision     = [bool]($overallStatus -eq 'GO')
    total_count     = $resultsList.Count
    passed_count    = $passedCount
    failed_count    = $failedCount
    blocked_count   = $blockedCount
    skipped_count   = $skippedCount
    results         = $resultsList
  }
}

function Invoke-AgentHubValidationPlan {
  param(
    [string]$WorktreePath,
    $ValidationPlan = @(),
    [string]$TaskId = '',
    $Contract = $null,
    [string[]]$Secrets = @(),
    [int]$DefaultTimeoutSeconds = 60
  )
  $results = [System.Collections.Generic.List[PSCustomObject]]::new()

  # 1. Enforce Worktree Isolation & Ownership
  if (-not [string]::IsNullOrWhiteSpace($TaskId)) {
    $ownershipCheck = Test-AgentHubWorktreeOwnership -WorktreePath $WorktreePath -ExpectedTaskId $TaskId
    if (-not $ownershipCheck.is_agenthub_worktree -or -not $ownershipCheck.matches_task) {
      # Foreign or mismatched worktree: Reject execution entirely
      foreach ($item in @($ValidationPlan)) {
        $results.Add([pscustomobject]@{
          validation_id         = $item.validation_id
          type                  = $item.type
          source                = $item.source
          required              = [bool]$item.required
          command_or_assertion  = $item.command_or_assertion
          working_directory     = $WorktreePath
          started_at            = (Get-Date).ToUniversalTime().ToString('o')
          finished_at           = (Get-Date).ToUniversalTime().ToString('o')
          duration_ms           = 0
          exit_code             = $null
          status                = 'BLOCKED'
          stdout_summary        = ''
          stderr_summary        = "FOREIGN_WORKTREE_REJECTED: Worktree at '$WorktreePath' is not owned by AgentHub task '$TaskId'"
          evidence_paths        = @()
        })
      }
      return Get-AgentHubValidationSummary -Results $results
    }
  }

  # 2. Execute each validation item
  foreach ($item in @($ValidationPlan)) {
    $res = Invoke-AgentHubValidationItem `
      -Item $item `
      -WorktreePath $WorktreePath `
      -Contract $Contract `
      -Secrets $Secrets `
      -DefaultTimeoutSeconds $DefaultTimeoutSeconds

    $results.Add($res)
  }

  return Get-AgentHubValidationSummary -Results $results
}

Export-ModuleMember -Function `
  Redact-AgentHubOutput, `
  Format-AgentHubBoundedOutput, `
  Resolve-AgentHubValidationPlan, `
  Invoke-AgentHubValidationItem, `
  Get-AgentHubValidationSummary, `
  Invoke-AgentHubValidationPlan
