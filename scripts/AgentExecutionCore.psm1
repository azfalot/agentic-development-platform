function Resolve-AgentExecutionSpecification {
  param([hashtable]$Adapter, [hashtable]$Context)
  $resolver = Get-Command $Adapter.resolve_function -CommandType Function -ErrorAction Stop
  & $resolver @Context
}

function Test-AgentExecutionSpecification {
  param([hashtable]$Adapter, $Specification)
  $tester = Get-Command $Adapter.test_function -CommandType Function -ErrorAction Stop
  & $tester -Specification $Specification
}

function Invoke-AgentExecutionSpecification {
  param(
    $Specification,
    [string]$StandardOutputPath,
    [string]$StandardErrorPath,
    [int]$TimeoutSeconds,
    [scriptblock]$ProcessRunner
  )
  if ($ProcessRunner) { return & $ProcessRunner $Specification }
  if (-not $Specification.executable -or -not $Specification.working_directory -or -not ($Specification.arguments -is [array])) { throw 'INVALID_EXECUTION_SPECIFICATION' }
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $Specification.executable
  $startInfo.WorkingDirectory = $Specification.working_directory
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in $Specification.arguments) { [void]$startInfo.ArgumentList.Add([string]$argument) }
  foreach ($name in $Specification.environment.Keys) { $startInfo.Environment[$name] = [string]$Specification.environment[$name] }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  $started = $process.Start()
  if (-not $started) { throw 'PROCESS_START_FAILED' }
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $completed = $process.WaitForExit($TimeoutSeconds * 1000)
  if (-not $completed) {
    $process.Kill($true)
    $process.WaitForExit()
  }
  [Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
  Set-Content -LiteralPath $StandardOutputPath -Value $stdoutTask.Result -Encoding utf8
  Set-Content -LiteralPath $StandardErrorPath -Value $stderrTask.Result -Encoding utf8
  [pscustomobject]@{ process_completed = $completed; exit_code = $process.ExitCode; process_id = $process.Id; specification_id = $Specification.specification_id }
}

Export-ModuleMember -Function Resolve-AgentExecutionSpecification,Test-AgentExecutionSpecification,Invoke-AgentExecutionSpecification
