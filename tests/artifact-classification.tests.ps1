# artifact-classification.tests.ps1
# Deterministic regression test matrix for AgentHub Artifact Classification (P0)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\scripts\ArtifactClassification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\scripts\ProgressClassifier.psm1') -Force

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function New-TestGitRepo {
  $path = Join-Path $env:TEMP ('agenthub-art-test-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $path | Out-Null
  git init -q $path
  git -C $path config user.email test@example.invalid
  git -C $path config user.name test
  Set-Content -LiteralPath (Join-Path $path 'README.md') '# Test'
  git -C $path add .
  git -C $path commit -qm 'initial commit'
  return $path
}

function New-TestContract([string[]]$Allowed, [string[]]$Forbidden = @('private/**')) {
  [pscustomobject]@{
    scope = [pscustomobject]@{
      allowed = $Allowed
      forbidden = $Forbidden
      bounded_context = 'test'
    }
    ownership = [pscustomobject]@{
      files = $Allowed
    }
  }
}

# -------------------------------------------------------------
# Case A: Allowed product source change -> PRODUCT_CHANGE + authorized
# -------------------------------------------------------------
$contractA = New-TestContract @('src/**')
$itemA = Get-AgentHubArtifactClassification -Path 'src/services/UserService.ts' -TrackedState 'UNTRACKED' -Contract $contractA
Assert ($itemA.classification -eq 'PRODUCT_CHANGE') 'A: Product source not classified as PRODUCT_CHANGE'
Assert ($itemA.scope_relevant -eq $true) 'A: Product source must be scope relevant'
Assert ($itemA.scope_decision -eq 'AUTHORIZED_PRODUCT') 'A: Allowed product source was not AUTHORIZED_PRODUCT'

# -------------------------------------------------------------
# Case B: Product source outside Task Contract -> SCOPE_VIOLATION
# -------------------------------------------------------------
$contractB = New-TestContract @('src/**')
$itemB = Get-AgentHubArtifactClassification -Path 'backend/core/Security.cs' -TrackedState 'UNTRACKED' -Contract $contractB
Assert ($itemB.classification -eq 'PRODUCT_CHANGE') 'B: Backend source not classified as PRODUCT_CHANGE'
Assert ($itemB.scope_relevant -eq $true) 'B: Backend source must be scope relevant'
Assert ($itemB.scope_decision -eq 'SCOPE_VIOLATION') 'B: Out-of-scope product source was not SCOPE_VIOLATION'

# -------------------------------------------------------------
# Case C: Untracked node_modules -> DEPENDENCY_ARTIFACT, disposable, no scope violation
# -------------------------------------------------------------
$contractC = New-TestContract @('src/**')
$itemC = Get-AgentHubArtifactClassification -Path 'node_modules/express/index.js' -TrackedState 'UNTRACKED' -Contract $contractC
Assert ($itemC.classification -eq 'DEPENDENCY_ARTIFACT') 'C: node_modules not classified as DEPENDENCY_ARTIFACT'
Assert ($itemC.scope_relevant -eq $false) 'C: Untracked node_modules must not be scope relevant'
Assert ($itemC.scope_decision -eq 'DISPOSABLE_IGNORED') 'C: Untracked node_modules must be DISPOSABLE_IGNORED'

# -------------------------------------------------------------
# Case D: Untracked .npm-cache and frontend/.npm-cache -> DEPENDENCY_ARTIFACT, disposable
# -------------------------------------------------------------
$contractD = New-TestContract @('src/**')
$itemD1 = Get-AgentHubArtifactClassification -Path '.npm-cache/_cacache/content-v2/sha512/abc' -TrackedState 'UNTRACKED' -Contract $contractD
$itemD2 = Get-AgentHubArtifactClassification -Path 'frontend/.npm-cache/anonymous-cli-metrics.json' -TrackedState 'UNTRACKED' -Contract $contractD
Assert ($itemD1.classification -eq 'DEPENDENCY_ARTIFACT') 'D1: .npm-cache not classified as DEPENDENCY_ARTIFACT'
Assert ($itemD1.scope_relevant -eq $false) 'D1: Untracked .npm-cache must not be scope relevant'
Assert ($itemD2.classification -eq 'DEPENDENCY_ARTIFACT') 'D2: Nested frontend/.npm-cache not classified as DEPENDENCY_ARTIFACT'
Assert ($itemD2.scope_relevant -eq $false) 'D2: Nested frontend/.npm-cache must not be scope relevant'

# -------------------------------------------------------------
# Case E: Playwright report -> TEST_ARTIFACT
# -------------------------------------------------------------
$contractE = New-TestContract @('src/**')
$itemE = Get-AgentHubArtifactClassification -Path 'playwright-report/index.html' -TrackedState 'UNTRACKED' -Contract $contractE
Assert ($itemE.classification -eq 'TEST_ARTIFACT') 'E: playwright-report not classified as TEST_ARTIFACT'
Assert ($itemE.scope_relevant -eq $false) 'E: Untracked playwright-report must not be scope relevant'
Assert ($itemE.scope_decision -eq 'DISPOSABLE_IGNORED') 'E: playwright-report must be DISPOSABLE_IGNORED'

# -------------------------------------------------------------
# Case F: test-results -> TEST_ARTIFACT
# -------------------------------------------------------------
$contractF = New-TestContract @('src/**')
$itemF = Get-AgentHubArtifactClassification -Path 'test-results/junit.xml' -TrackedState 'UNTRACKED' -Contract $contractF
Assert ($itemF.classification -eq 'TEST_ARTIFACT') 'F: test-results not classified as TEST_ARTIFACT'
Assert ($itemF.scope_relevant -eq $false) 'F: Untracked test-results must not be scope relevant'

# -------------------------------------------------------------
# Case G: Maven target/ -> BUILD_ARTIFACT
# -------------------------------------------------------------
$contractG = New-TestContract @('src/**')
$itemG = Get-AgentHubArtifactClassification -Path 'target/classes/com/example/App.class' -TrackedState 'UNTRACKED' -Contract $contractG
Assert ($itemG.classification -eq 'BUILD_ARTIFACT') 'G: Maven target not classified as BUILD_ARTIFACT'
Assert ($itemG.scope_relevant -eq $false) 'G: Untracked Maven target must not be scope relevant'

# -------------------------------------------------------------
# Case H: Gradle build/ -> BUILD_ARTIFACT
# -------------------------------------------------------------
$contractH = New-TestContract @('src/**')
$itemH = Get-AgentHubArtifactClassification -Path 'build/libs/service-1.0.0.jar' -TrackedState 'UNTRACKED' -Contract $contractH
Assert ($itemH.classification -eq 'BUILD_ARTIFACT') 'H: Gradle build not classified as BUILD_ARTIFACT'
Assert ($itemH.scope_relevant -eq $false) 'H: Untracked Gradle build must not be scope relevant'

# -------------------------------------------------------------
# Case I: .NET bin/obj -> BUILD_ARTIFACT
# -------------------------------------------------------------
$contractI = New-TestContract @('src/**')
$itemI1 = Get-AgentHubArtifactClassification -Path 'src/Core/bin/Debug/net8.0/Core.dll' -TrackedState 'UNTRACKED' -Contract $contractI
$itemI2 = Get-AgentHubArtifactClassification -Path 'src/Core/obj/Debug/net8.0/Core.csproj.FileListAbsolute.txt' -TrackedState 'UNTRACKED' -Contract $contractI
Assert ($itemI1.classification -eq 'BUILD_ARTIFACT') 'I1: .NET bin not classified as BUILD_ARTIFACT'
Assert ($itemI1.scope_relevant -eq $false) 'I1: Untracked .NET bin must not be scope relevant'
Assert ($itemI2.classification -eq 'BUILD_ARTIFACT') 'I2: .NET obj not classified as BUILD_ARTIFACT'
Assert ($itemI2.scope_relevant -eq $false) 'I2: Untracked .NET obj must not be scope relevant'

# -------------------------------------------------------------
# Case J: AgentHub evidence/runtime files -> AGENTHUB_EVIDENCE
# -------------------------------------------------------------
$contractJ = New-TestContract @('src/**')
$itemJ1 = Get-AgentHubArtifactClassification -Path '.agenthub/worktree-ownership.json' -TrackedState 'UNTRACKED' -Contract $contractJ
$itemJ2 = Get-AgentHubArtifactClassification -Path '.agenthub-evidence-20260921000000.json' -TrackedState 'UNTRACKED' -Contract $contractJ
$itemJ3 = Get-AgentHubArtifactClassification -Path 'TASK_CONTRACT.json' -TrackedState 'UNTRACKED' -Contract $contractJ
Assert ($itemJ1.classification -eq 'AGENTHUB_EVIDENCE') 'J1: .agenthub/ not classified as AGENTHUB_EVIDENCE'
Assert ($itemJ1.scope_relevant -eq $false) 'J1: .agenthub/ must not be scope relevant'
Assert ($itemJ2.classification -eq 'AGENTHUB_EVIDENCE') 'J2: .agenthub-evidence not classified as AGENTHUB_EVIDENCE'
Assert ($itemJ3.classification -eq 'AGENTHUB_EVIDENCE') 'J3: TASK_CONTRACT.json not classified as AGENTHUB_EVIDENCE'

# -------------------------------------------------------------
# Case K: Documentation file inside declared documentation scope -> DOCUMENTATION_CHANGE
# -------------------------------------------------------------
$contractK = New-TestContract @('docs/**')
$itemK = Get-AgentHubArtifactClassification -Path 'docs/architecture/adr-001.md' -TrackedState 'UNTRACKED' -Contract $contractK
Assert ($itemK.classification -eq 'DOCUMENTATION_CHANGE') 'K: Docs not classified as DOCUMENTATION_CHANGE'
Assert ($itemK.scope_relevant -eq $true) 'K: Docs must be scope relevant'
Assert ($itemK.scope_decision -eq 'AUTHORIZED_DOCUMENTATION') 'K: Allowed doc not AUTHORIZED_DOCUMENTATION'

# -------------------------------------------------------------
# Case L: Test source file -> TEST_CHANGE (not disposable test output)
# -------------------------------------------------------------
$contractL = New-TestContract @('tests/**')
$itemL1 = Get-AgentHubArtifactClassification -Path 'tests/unit/UserService.test.ts' -TrackedState 'UNTRACKED' -Contract $contractL
$itemL2 = Get-AgentHubArtifactClassification -Path 'src/components/Button.spec.tsx' -TrackedState 'UNTRACKED' -Contract $contractL
Assert ($itemL1.classification -eq 'TEST_CHANGE') 'L1: Test source not classified as TEST_CHANGE'
Assert ($itemL1.scope_relevant -eq $true) 'L1: Test source must be scope relevant'
Assert ($itemL1.scope_decision -eq 'AUTHORIZED_TEST') 'L1: Allowed test source not AUTHORIZED_TEST'
Assert ($itemL2.classification -eq 'TEST_CHANGE') 'L2: Component spec not classified as TEST_CHANGE'
Assert ($itemL2.scope_relevant -eq $true) 'L2: Component spec must be scope relevant'

# -------------------------------------------------------------
# Case M: Tracked dist/ file modified -> remains scope relevant
# -------------------------------------------------------------
$repoM = New-TestGitRepo
try {
  $distDir = Join-Path $repoM 'dist'
  New-Item -ItemType Directory -Path $distDir | Out-Null
  Set-Content -LiteralPath (Join-Path $distDir 'bundle.js') '// tracked bundle'
  git -C $repoM add .
  git -C $repoM commit -qm 'track dist'

  $trackedState = Get-AgentHubTrackedState -Path 'dist/bundle.js' -RepositoryPath $repoM
  Assert ($trackedState -eq 'TRACKED') 'M: Tracked dist file was not detected as TRACKED'

  $contractM = New-TestContract @('src/**') # dist is NOT allowed
  $itemM = Get-AgentHubArtifactClassification -Path 'dist/bundle.js' -RepositoryPath $repoM -Contract $contractM
  Assert ($itemM.classification -eq 'BUILD_ARTIFACT') 'M: dist/bundle.js not classified as BUILD_ARTIFACT'
  Assert ($itemM.tracked_state -eq 'TRACKED') 'M: Tracked state mismatch'
  Assert ($itemM.scope_relevant -eq $true) 'M: Intentionally tracked build artifact MUST remain scope relevant'
  Assert ($itemM.scope_decision -eq 'SCOPE_VIOLATION') 'M: Out-of-scope tracked build artifact was not SCOPE_VIOLATION'
} finally {
  Remove-Item -LiteralPath $repoM -Recurse -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------
# Case N: UNKNOWN untracked file -> not silently discarded
# -------------------------------------------------------------
$contractN = New-TestContract @('src/**')
$itemN = Get-AgentHubArtifactClassification -Path 'unrecognized/secret_key.bin' -TrackedState 'UNTRACKED' -Contract $contractN
Assert ($itemN.classification -eq 'UNKNOWN') 'N: Unrecognized file not classified as UNKNOWN'
Assert ($itemN.scope_relevant -eq $true) 'N: UNKNOWN file must be scope relevant (fail-safe)'
Assert ($itemN.scope_decision -eq 'SCOPE_VIOLATION') 'N: Out-of-scope UNKNOWN file was not SCOPE_VIOLATION'

# -------------------------------------------------------------
# Case O: Mixed diff (valid product file + node_modules + Playwright report) -> valid progress, no false scope violation
# -------------------------------------------------------------
$contractO = New-TestContract @('src/**', 'tests/**')
$changedO = @(
  'src/index.ts',
  'tests/index.spec.ts',
  'node_modules/lodash/index.js',
  'playwright-report/index.html',
  'frontend/.npm-cache/lockfile.json'
)
$resO = Get-AgentHubChangeClassification -ChangedFiles $changedO -Contract $contractO
Assert ($resO.scope_valid -eq $true) 'O: Disposable runtime artifacts caused a false scope violation'
Assert ($resO.source_change_detected -eq $true) 'O: Source change was not detected'
Assert ($resO.test_change_detected -eq $true) 'O: Test change was not detected'
Assert ($resO.progress_detected -eq $true) 'O: Valid progress was not detected'
Assert ($resO.invalid_files.Count -eq 0) 'O: Unexpected invalid files'
Assert ($resO.disposable_files.Count -eq 3) 'O: Disposable files count mismatch'

# -------------------------------------------------------------
# Case P: Mixed diff (valid product file + genuine out-of-scope source + runtime artifacts) -> SCOPE_VIOLATION
# -------------------------------------------------------------
$contractP = New-TestContract @('src/**', 'tests/**')
$changedP = @(
  'src/index.ts',
  'tests/index.spec.ts',
  'secrets/database.conf',
  'node_modules/axios/index.js'
)
$resP = Get-AgentHubChangeClassification -ChangedFiles $changedP -Contract $contractP
Assert ($resP.scope_valid -eq $false) 'P: Genuine out-of-scope file was not detected as scope violation'
Assert ($resP.invalid_files -contains 'secrets/database.conf') 'P: Invalid files missing secrets/database.conf'
Assert ($resP.disposable_files -contains 'node_modules/axios/index.js') 'P: Disposable files missing node_modules'

# -------------------------------------------------------------
# Case Q: RUNTIME_ARTIFACT_FALSE_SCOPE_REGRESSION
# (generated test spec + nested frontend/.npm-cache/)
# -> Test spec remains scope-relevant, .npm-cache classified disposable, no false violation
# -------------------------------------------------------------
$contractQ = New-TestContract @('src/**', 'tests/e2e/**')
$changedQ = @(
  'src/features/search.ts',
  'tests/e2e/search-workflow.spec.ts',
  'frontend/.npm-cache/_cacache/index-v5/12/34/56',
  'frontend/.npm-cache/anonymous-cli-metrics.json'
)
$resQ = Get-AgentHubChangeClassification -ChangedFiles $changedQ -Contract $contractQ
Assert ($resQ.scope_valid -eq $true) 'Q: Nested .npm-cache runtime artifact caused false scope violation'
Assert ($resQ.progress_detected -eq $true) 'Q: Valid progress with runtime artifacts was not recognized'
Assert ($resQ.test_files -contains 'tests/e2e/search-workflow.spec.ts') 'Q: Test spec missing from test_files'
Assert ($resQ.implementation_files -contains 'src/features/search.ts') 'Q: Feature missing from implementation_files'
Assert ($resQ.disposable_files.Count -eq 2) 'Q: Disposable cache count mismatch'

Write-Output 'Artifact classification matrix A-Q passed without model invocation.'
exit 0
