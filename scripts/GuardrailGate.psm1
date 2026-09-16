function Get-GuardrailIdentity {
  param($Finding)
  "$($Finding.rule)|$($Finding.repository)|$($Finding.path)"
}

function Test-GuardrailBaseline {
  param($Baseline)
  if(-not $Baseline -or $Baseline.schema_version -ne 1 -or -not $Baseline.initialization -or -not ($Baseline.findings -is [array])){throw 'GUARDRAIL_BASELINE_INVALID'}
  $seen=@{}
  foreach($finding in $Baseline.findings){
    if(-not $finding.id -or -not $finding.rule -or -not $finding.repository -or -not $finding.path -or $seen[$finding.id]){throw 'GUARDRAIL_BASELINE_INVALID'}
    if($finding.id -ne (Get-GuardrailIdentity $finding)){throw 'GUARDRAIL_BASELINE_INVALID'}
    $seen[$finding.id]=$true
  }
  $true
}

function Compare-GuardrailFindings {
  param($Baseline,$Current,[string]$TaskRepository='')
  Test-GuardrailBaseline $Baseline | Out-Null
  $baselineById=@{};foreach($finding in $Baseline.findings){$baselineById[$finding.id]=$finding}
  $currentById=@{}
  foreach($raw in $Current){
    $id=Get-GuardrailIdentity $raw
    if($currentById[$id]){continue}
    $currentById[$id]=[pscustomobject]@{id=$id;rule=$raw.rule;repository=$raw.repository;path=$raw.path}
  }
  $unchanged=@($currentById.Keys|Where-Object{$baselineById.ContainsKey($_)}|Sort-Object|ForEach-Object{$currentById[$_]})
  $new=@($currentById.Keys|Where-Object{-not $baselineById.ContainsKey($_)}|Sort-Object|ForEach-Object{$currentById[$_]})
  $resolved=@($baselineById.Keys|Where-Object{-not $currentById.ContainsKey($_)}|Sort-Object|ForEach-Object{$baselineById[$_]})
  $taskNew=@($new|Where-Object{if(-not $TaskRepository){$true}else{$_.path -like ($TaskRepository.Replace('\','/').TrimEnd('/')+'/*') -or $_.repository -eq $TaskRepository}})
  [pscustomobject]@{
    global_guardrail_status=if($currentById.Count){'FINDINGS_PRESENT'}else{'CLEAN'}
    task_guardrail_gate=if($new.Count){'FAIL_NEW_REGRESSION'}else{'PASS_NO_NEW_REGRESSIONS'}
    baseline_count=$baselineById.Count
    current_count=$currentById.Count
    unchanged_baseline_count=$unchanged.Count
    new_regression_count=$new.Count
    resolved_baseline_count=$resolved.Count
    baseline_findings=$unchanged
    new_regressions=$new
    resolved_baseline=$resolved
    task_scope_new_regressions=$taskNew
  }
}

Export-ModuleMember -Function Get-GuardrailIdentity,Test-GuardrailBaseline,Compare-GuardrailFindings
