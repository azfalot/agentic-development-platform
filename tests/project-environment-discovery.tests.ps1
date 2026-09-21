$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\scripts\ProjectEnvironmentDiscovery.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\scripts\EnvironmentReadiness.psm1') -Force

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function New-TestRepo {
  $path = Join-Path $env:TEMP ('agenthub-discovery-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $path | Out-Null
  git init -q $path
  git -C $path config user.email test@example.invalid
  git -C $path config user.name test
  return $path
}

function New-TestContract([string]$Repository, [hashtable]$Environment = $null) {
  $c = @{
    schema_version = 2
    task = @{ id = ('discovery-' + [guid]::NewGuid().ToString('N')); source = 'test'; repository = $Repository; issue = $null }
    goal = 'Discovery test'
    assignment = @{ role = 'implementer'; engine = 'codex' }
    state = 'READY'
    scope = @{ bounded_context = 'test'; allowed = @('**'); forbidden = @('AGENTS.md', '.git/**') }
    permissions = @{ filesystem = 'scoped-write'; git_write = $true; github_write = $true; merge = $false; production = 'denied' }
    ownership = @{ task = 'discovery'; branch = ('feature/discovery-' + [guid]::NewGuid().ToString('N')); bounded_context = 'test'; files = @('**'); migrations = @() }
    acceptance_criteria = @()
    verification = @{ build = 'NOT_RUN'; lint = 'NOT_RUN'; unit = 'NOT_RUN'; integration = 'NOT_APPLICABLE'; e2e = 'NOT_RUN'; guardrails = 'NOT_RUN'; ci = 'NOT_RUN' }
    evidence = @{ commit_sha = $null; changed_files = @(); test_results = @(); build_result = $null; playwright = $null; ci = $null; pull_request = $null }
    handoff = @{ target_role = 'human'; reason = 'test' }
    timestamps = @{ created = '2026-09-21T00:00:00Z'; updated = '2026-09-21T00:00:00Z' }
  }
  if ($Environment) { $c.environment = $Environment }
  return $c
}

# -------------------------------------------------------------
# Case A: Node + package-lock -> npm detected
# -------------------------------------------------------------
$repoA = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoA 'package.json') '{"name":"test-node","version":"1.0.0"}'
  Set-Content -LiteralPath (Join-Path $repoA 'package-lock.json') '{"name":"test-node","lockfileVersion":3}'
  $discA = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoA
  Assert ($discA.ecosystems -contains 'node') 'A: Node ecosystem was not detected'
  Assert ($discA.package_manager.type -eq 'npm') 'A: npm package manager was not detected'
  Assert ($discA.package_manager.source -eq 'package-lock.json') 'A: package-lock.json was not identified as source'
} finally { Remove-Item -LiteralPath $repoA -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case B: Node + missing installed dependencies -> dependency state detected
# -------------------------------------------------------------
$repoB = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoB 'package.json') '{"name":"test-missing-deps","dependencies":{"express":"^4.18.0"}}'
  Set-Content -LiteralPath (Join-Path $repoB 'package-lock.json') '{"name":"test-missing-deps","lockfileVersion":3}'
  $discB = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoB
  Assert ($discB.dependencies.status -eq 'MISSING') 'B: Missing dependencies status was not MISSING'
  Assert ($discB.dependencies.path -eq 'node_modules') 'B: Expected node_modules path'
  
  # When node_modules exists and is populated
  $nmDir = Join-Path $repoB 'node_modules'
  New-Item -ItemType Directory -Path (Join-Path $nmDir 'express') | Out-Null
  Set-Content -LiteralPath (Join-Path (Join-Path $nmDir 'express') 'package.json') '{}'
  $discBReady = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoB
  Assert ($discBReady.dependencies.status -eq 'READY') 'B: Populated node_modules did not resolve to READY'
} finally { Remove-Item -LiteralPath $repoB -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case C: Playwright declared in project -> verification tooling discovered
# -------------------------------------------------------------
$repoC = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoC 'package.json') '{"name":"test-playwright","devDependencies":{"@playwright/test":"^1.40.0"}}'
  Set-Content -LiteralPath (Join-Path $repoC 'playwright.config.ts') 'import { defineConfig } from "@playwright/test"; export default defineConfig({});'
  $discC = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoC
  Assert ($discC.verification_tools.playwright.declared -eq $true) 'C: Playwright was not discovered as declared'
  Assert ($discC.verification_tools.playwright.source -match 'playwright\.config\.ts') 'C: Playwright config source was not detected'
} finally { Remove-Item -LiteralPath $repoC -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case D: Compose file present -> Compose detected
# -------------------------------------------------------------
$repoD = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoD 'docker-compose.yml') 'version: "3.8"'
  $discD = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoD
  Assert ($discD.docker.compose_detected -eq $true) 'D: docker-compose.yml was not detected'
  Assert ($discD.docker.compose_file -eq 'docker-compose.yml') 'D: docker-compose.yml path mismatch'
} finally { Remove-Item -LiteralPath $repoD -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case E: Docker unavailable -> correctly represented, not fabricated READY
# -------------------------------------------------------------
$repoE = New-TestRepo
try {
  $discE = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoE
  # Verify docker_available reflects actual system command status deterministically
  $realDocker = [bool](Get-Command docker -ErrorAction SilentlyContinue)
  Assert ($discE.docker.docker_available -eq $realDocker) 'E: docker_available did not match actual environment'
} finally { Remove-Item -LiteralPath $repoE -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case F: Java + Maven wrapper -> ecosystem/tooling detected
# -------------------------------------------------------------
$repoF = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoF 'pom.xml') '<project><modelVersion>4.0.0</modelVersion></project>'
  Set-Content -LiteralPath (Join-Path $repoF 'mvnw') '#!/bin/sh'
  Set-Content -LiteralPath (Join-Path $repoF 'mvnw.cmd') '@rem Maven wrapper'
  $discF = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoF
  Assert ($discF.ecosystems -contains 'maven') 'F: Maven ecosystem was not detected'
  Assert ($discF.package_manager.type -eq 'mvnw') 'F: mvnw package manager type was not detected'
  Assert ($discF.verification_tools.maven_wrapper.declared -eq $true) 'F: Maven wrapper verification tool was not detected'
} finally { Remove-Item -LiteralPath $repoF -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case G: Java + Gradle wrapper -> ecosystem/tooling detected
# -------------------------------------------------------------
$repoG = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoG 'build.gradle') 'plugins { id "java" }'
  Set-Content -LiteralPath (Join-Path $repoG 'gradlew') '#!/bin/sh'
  Set-Content -LiteralPath (Join-Path $repoG 'gradlew.bat') '@rem Gradle wrapper'
  $discG = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoG
  Assert ($discG.ecosystems -contains 'gradle') 'G: Gradle ecosystem was not detected'
  Assert ($discG.package_manager.type -eq 'gradlew') 'G: gradlew package manager type was not detected'
  Assert ($discG.verification_tools.gradle_wrapper.declared -eq $true) 'G: Gradle wrapper verification tool was not detected'
} finally { Remove-Item -LiteralPath $repoG -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case H: Explicit contract declaration overrides inference
# -------------------------------------------------------------
$repoH = New-TestRepo
try {
  # Repo has Node package.json and missing node_modules (which would normally infer node_modules dependency)
  Set-Content -LiteralPath (Join-Path $repoH 'package.json') '{"name":"override-test"}'
  # Explicit contract defines custom dependencies and empty required commands
  $customDep = Join-Path $repoH 'custom.txt'
  Set-Content -LiteralPath $customDep 'custom ready'
  $explicitEnv = @{
    required_commands = @(@{ name = 'pwsh'; required = $true })
    dependencies = @(@{ name = 'custom-dependency'; path = 'custom.txt'; required = $true })
    services = @()
    verification_commands = @()
    preparation = @{ allowed = $false; actions = @() }
  }
  $contractH = New-TestContract $repoH $explicitEnv
  $readinessH = Get-EnvironmentReadiness -Contract $contractH -WorkingDirectory $repoH
  Assert ($readinessH.state -eq 'READY') 'H: Explicit contract overrides were not honored (readiness was not READY)'
  $depChecks = @($readinessH.checks | Where-Object { $_.kind -eq 'dependency' })
  Assert ($depChecks.Count -eq 1 -and $depChecks[0].name -eq 'custom-dependency') 'H: Inferred dependencies leaked through explicit contract override'
} finally { Remove-Item -LiteralPath $repoH -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case I: Unsupported / unknown project -> UNKNOWN, safe behavior
# -------------------------------------------------------------
$repoI = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoI 'README.txt') 'Arbitrary plain text repo'
  Set-Content -LiteralPath (Join-Path $repoI 'data.bin') '12345'
  $discI = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoI
  Assert ($discI.ecosystems -contains 'unknown') 'I: Unsupported project did not report unknown ecosystem'
  Assert ($discI.package_manager.type -eq 'unknown') 'I: Unsupported project did not report unknown package manager'
} finally { Remove-Item -LiteralPath $repoI -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case J: Optional unknown capability -> does not unnecessarily block
# -------------------------------------------------------------
$repoJ = New-TestRepo
try {
  Set-Content -LiteralPath (Join-Path $repoJ 'notes.txt') 'Generic project without strict framework'
  $contractJ = New-TestContract $repoJ
  $readinessJ = Get-EnvironmentReadiness -Contract $contractJ -WorkingDirectory $repoJ
  Assert ($readinessJ.state -eq 'READY') 'J: Optional unknown ecosystem unnecessarily blocked environment readiness'
} finally { Remove-Item -LiteralPath $repoJ -Recurse -Force -ErrorAction SilentlyContinue }

# -------------------------------------------------------------
# Case K: Sandbox / write capability unavailable -> detected before agent execution
# -------------------------------------------------------------
$nonExistentPath = 'Z:\__agenthub_non_existent_drive_or_restricted_path__' + [guid]::NewGuid().ToString('N')
$sandProbe = Test-EnvironmentSandboxCapability -WorkingDirectory $nonExistentPath -FilesystemPermission 'scoped-write'
Assert ($sandProbe.writable -eq $false) 'K: Non-existent directory was marked writable'
Assert ($sandProbe.compatible -eq $false) 'K: Non-existent directory was marked compatible'

$contractK = New-TestContract $nonExistentPath
$readinessK = Get-EnvironmentReadiness -Contract $contractK -WorkingDirectory $nonExistentPath
Assert ($readinessK.state -eq 'BLOCKED') 'K: Inaccessible execution location was not BLOCKED before agent execution'
$writeCheck = @($readinessK.checks | Where-Object { $_.name -eq 'write-capability' })[0]
Assert ($writeCheck.passed -eq $false) 'K: write-capability check did not fail'

# -------------------------------------------------------------
# Case L: Polyglot monorepo project fixture -> Node/Playwright/Docker requirements discovered without manually declaring every low-level prerequisite
# -------------------------------------------------------------
$repoL = New-TestRepo
try {
  # Polyglot frontend/backend subproject layout
  $frontendDir = Join-Path $repoL 'frontend'
  $backendDir = Join-Path $repoL 'backend'
  New-Item -ItemType Directory -Path $frontendDir | Out-Null
  New-Item -ItemType Directory -Path $backendDir | Out-Null
  
  Set-Content -LiteralPath (Join-Path $frontendDir 'package.json') '{"name":"polyglot-frontend","devDependencies":{"@playwright/test":"^1.40.0"}}'
  Set-Content -LiteralPath (Join-Path $frontendDir 'package-lock.json') '{"name":"polyglot-frontend","lockfileVersion":3}'
  Set-Content -LiteralPath (Join-Path $frontendDir 'playwright.config.ts') 'export default {};'
  
  Set-Content -LiteralPath (Join-Path $backendDir 'pom.xml') '<project><modelVersion>4.0.0</modelVersion></project>'
  Set-Content -LiteralPath (Join-Path $backendDir 'mvnw') '#!/bin/sh'
  
  Set-Content -LiteralPath (Join-Path $repoL 'docker-compose.yml') 'version: "3.8"'
  
  # Contract with NO environment block
  $contractL = New-TestContract $repoL
  $contractL.verification.e2e = 'NOT_RUN' # E2E Playwright is requested
  
  $discL = Get-ProjectEnvironmentDiscovery -WorkingDirectory $repoL -Contract $contractL
  Assert ($discL.ecosystems -contains 'node') 'L: Polyglot Node frontend not discovered'
  Assert ($discL.ecosystems -contains 'maven') 'L: Polyglot Maven backend not discovered'
  Assert ($discL.docker.compose_detected -eq $true) 'L: Polyglot Docker Compose not discovered'
  Assert ($discL.verification_tools.playwright.declared -eq $true) 'L: Polyglot Playwright not discovered'
  Assert ($discL.dependencies.status -eq 'MISSING') 'L: Missing frontend node_modules was not discovered'
  
  # Readiness evaluation without manual contract declaration
  $readinessL = Get-EnvironmentReadiness -Contract $contractL -WorkingDirectory $repoL -Discovery $discL
  Assert ($readinessL.state -eq 'BLOCKED') 'L: Missing node_modules did not deterministically block readiness'
  $depBlocker = @($readinessL.blockers | Where-Object { $_.kind -eq 'dependency' })
  Assert ($depBlocker.Count -gt 0) 'L: Dependency blocker was not recorded'
} finally { Remove-Item -LiteralPath $repoL -Recurse -Force -ErrorAction SilentlyContinue }

Write-Output 'Project environment discovery matrix A-L passed without model invocation.'
