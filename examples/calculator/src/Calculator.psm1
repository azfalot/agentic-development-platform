function Add-Numbers { param([int]$Left,[int]$Right) $Left + $Right }
function Divide-Numbers { param([int]$Left,[int]$Right) if($Right -eq 0){throw 'DIVIDE_BY_ZERO'}; [double]$Left / [double]$Right }
Export-ModuleMember -Function Add-Numbers,Divide-Numbers
