$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\Calculator.psm1') -Force
if((Add-Numbers 2 3) -ne 5){throw 'ADD_FAILED'}
if((Divide-Numbers 8 2) -ne 4){throw 'DIVIDE_FAILED'}
try { Divide-Numbers 1 0; throw 'DIVIDE_BY_ZERO_ACCEPTED' } catch { if($_.Exception.Message -ne 'DIVIDE_BY_ZERO'){throw} }
Write-Output 'CALCULATOR_TESTS_PASSED'
