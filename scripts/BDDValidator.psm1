Set-StrictMode -Version Latest

$script:Roles = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\bdd\v2\roles.psd1')
$script:States = @('CREATED','PLANNING','READY','CLAIMED','IMPLEMENTING','VERIFYING','REVIEWING','BLOCKED','READY_FOR_HUMAN','DONE','FAILED','CANCELLED')
$script:Transitions = @{
  CREATED = @('PLANNING','CANCELLED','FAILED'); PLANNING = @('READY','BLOCKED','FAILED','CANCELLED'); READY = @('CLAIMED','BLOCKED','CANCELLED'); CLAIMED = @('IMPLEMENTING','BLOCKED','CANCELLED','FAILED'); IMPLEMENTING = @('VERIFYING','BLOCKED','FAILED','CANCELLED'); VERIFYING = @('REVIEWING','IMPLEMENTING','BLOCKED','FAILED','CANCELLED'); REVIEWING = @('READY_FOR_HUMAN','IMPLEMENTING','BLOCKED','FAILED','CANCELLED'); BLOCKED = @('PLANNING','READY','CLAIMED','IMPLEMENTING','VERIFYING','REVIEWING','FAILED','CANCELLED'); READY_FOR_HUMAN = @('DONE','IMPLEMENTING','BLOCKED','FAILED','CANCELLED'); DONE = @(); FAILED = @(); CANCELLED = @()
}

function Test-BddStateTransition {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$From, [Parameter(Mandatory)][string]$To)
  if ($From -notin $script:States -or $To -notin $script:States) { return $false }
  return $To -in $script:Transitions[$From]
}

function Test-BddV2Contract {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  $errors = [System.Collections.Generic.List[string]]::new()
  try { $contract = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 32 } catch { return [pscustomobject]@{ IsValid = $false; Errors = @("Invalid JSON: $($_.Exception.Message)") } }
  $required = @('schema_version','task','goal','assignment','state','scope','permissions','ownership','acceptance_criteria','verification','evidence','handoff','timestamps')
  $allowedTopLevel = @($required + 'environment')
  foreach ($key in $required) { if (-not $contract.ContainsKey($key)) { $errors.Add("Missing top-level field: $key") } }
  foreach ($key in $contract.Keys) { if ($key -notin $allowedTopLevel) { $errors.Add("Unknown top-level field: $key") } }
  if ($contract.schema_version -ne 2) { $errors.Add('schema_version must be 2') }
  foreach ($section in @(@('task',@('id','source','repository','issue')), @('assignment',@('role','engine')), @('scope',@('bounded_context','allowed','forbidden')), @('permissions',@('filesystem','git_write','github_write','merge','production')), @('ownership',@('task','branch','bounded_context','files','migrations')), @('verification',@('build','lint','unit','integration','e2e','guardrails','ci')), @('evidence',@('commit_sha','changed_files','test_results','build_result','playwright','ci','pull_request')), @('handoff',@('target_role','reason')), @('timestamps',@('created','updated')))) { if ($contract[$section[0]] -isnot [hashtable]) { $errors.Add("$($section[0]) must be an object"); continue }; foreach ($key in $section[1]) { if (-not $contract[$section[0]].ContainsKey($key)) { $errors.Add("Missing $($section[0]).$key") } } }
  foreach ($section in @(@('task',@('id','source','repository','issue')), @('assignment',@('role','engine')), @('scope',@('bounded_context','allowed','forbidden')), @('permissions',@('filesystem','git_write','github_write','merge','production')), @('ownership',@('task','branch','bounded_context','files','migrations')), @('verification',@('build','lint','unit','integration','e2e','guardrails','ci')), @('evidence',@('commit_sha','changed_files','test_results','build_result','playwright','ci','pull_request')), @('handoff',@('target_role','reason')), @('timestamps',@('created','updated')))) { if ($contract[$section[0]] -is [hashtable]) { foreach ($key in $contract[$section[0]].Keys) { if ($key -notin $section[1]) { $errors.Add("Unknown $($section[0]).$key") } } } }
  if ($contract.assignment.role -notin $script:Roles.Keys) { $errors.Add('assignment.role is not canonical') }
  elseif ($contract.permissions -is [hashtable]) { foreach ($key in $script:Roles[$contract.assignment.role].permissions.Keys) { if ($contract.permissions[$key] -ne $script:Roles[$contract.assignment.role].permissions[$key]) { $errors.Add("permissions.$key exceeds or differs from the canonical $($contract.assignment.role) role") } } }
  if ($contract.state -notin $script:States) { $errors.Add('state is not canonical') }
  if ($contract.permissions.filesystem -notin @('none','read-only','scoped-write')) { $errors.Add('permissions.filesystem is invalid') }
  if ($contract.permissions.production -notin @('denied','approval-required','allowed')) { $errors.Add('permissions.production is invalid') }
  foreach ($key in @('git_write','github_write','merge')) { if ($contract.permissions[$key] -isnot [bool]) { $errors.Add("permissions.$key must be boolean") } }
  foreach ($key in @('allowed','forbidden')) { if ($contract.scope[$key] -isnot [System.Collections.IEnumerable] -or $contract.scope[$key] -is [string]) { $errors.Add("scope.$key must be an array") } }
  foreach ($key in @('files','migrations')) { if ($contract.ownership[$key] -isnot [System.Collections.IEnumerable] -or $contract.ownership[$key] -is [string]) { $errors.Add("ownership.$key must be an array") } }
  if ($contract.acceptance_criteria -isnot [System.Collections.IEnumerable] -or $contract.acceptance_criteria -is [string]) { $errors.Add('acceptance_criteria must be an array') }
  else { foreach ($criterion in $contract.acceptance_criteria) { if ($criterion -isnot [System.Collections.IDictionary]) { $errors.Add('Every acceptance criterion requires id, description, and status'); continue }; $missingCriterionFields = @(@('id','description','status') | Where-Object { -not $criterion.Contains($_) }); if ($missingCriterionFields.Count -gt 0) { $errors.Add('Every acceptance criterion requires id, description, and status') } elseif ($criterion.status -notin @('PENDING','PASSED','FAILED','NOT_APPLICABLE')) { $errors.Add('acceptance criterion status is invalid') } } }
  foreach ($key in @('build','lint','unit','integration','e2e','guardrails','ci')) { if ($contract.verification[$key] -notin @('NOT_RUN','PASSED','FAILED','SKIPPED','NOT_APPLICABLE')) { $errors.Add("verification.$key is invalid") } }
  foreach ($key in @('changed_files','test_results')) { if ($contract.evidence[$key] -isnot [System.Collections.IEnumerable] -or $contract.evidence[$key] -is [string]) { $errors.Add("evidence.$key must be an array") } }
  foreach ($key in @('created','updated')) { $value = $contract.timestamps[$key]; if ($value -is [DateTime] -or $value -is [DateTimeOffset]) { continue }; try { [DateTimeOffset]::Parse([string]$value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind) | Out-Null } catch { $errors.Add("timestamps.$key must be ISO-8601") } }
  if ($contract.ContainsKey('environment')) {
    $environment = $contract.environment
    if ($environment -isnot [hashtable]) { $errors.Add('environment must be an object') }
    else {
      $environmentRequired = @('required_commands','dependencies','services','verification_commands','preparation')
      foreach ($key in $environmentRequired) { if (-not $environment.ContainsKey($key)) { $errors.Add("Missing environment.$key") } }
      foreach ($key in $environment.Keys) { if ($key -notin $environmentRequired) { $errors.Add("Unknown environment.$key") } }
      foreach ($key in @('required_commands','dependencies','services','verification_commands')) { if ($environment.ContainsKey($key) -and ($environment[$key] -isnot [System.Collections.IEnumerable] -or $environment[$key] -is [string])) { $errors.Add("environment.$key must be an array") } }
      if ($environment.preparation -isnot [hashtable] -or -not $environment.preparation.ContainsKey('allowed') -or -not $environment.preparation.ContainsKey('actions')) { $errors.Add('environment.preparation must define allowed and actions') }
      elseif ($environment.preparation.allowed -isnot [bool] -or $environment.preparation.actions -isnot [System.Collections.IEnumerable] -or $environment.preparation.actions -is [string]) { $errors.Add('environment.preparation is invalid') }
    }
  }
  return [pscustomobject]@{ IsValid = ($errors.Count -eq 0); Errors = @($errors) }
}

function Get-BddRoleDefinition { [CmdletBinding()] param([Parameter(Mandatory)][string]$Role); if ($Role -notin $script:Roles.Keys) { throw "Unknown canonical role: $Role" }; return $script:Roles[$Role] }
Export-ModuleMember -Function Test-BddStateTransition, Test-BddV2Contract, Get-BddRoleDefinition
