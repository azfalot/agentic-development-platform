Set-StrictMode -Version Latest

function Test-EnvironmentSandboxCapability {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [string]$FilesystemPermission = 'scoped-write'
  )
  $exists = $false
  try {
    $exists = Test-Path -LiteralPath $WorkingDirectory
  } catch {
    return [pscustomobject]@{
      writable = $false
      compatible = $false
      detail = $_.Exception.Message
      source = 'filesystem-probe'
    }
  }
  if (-not $exists) {
    return [pscustomobject]@{
      writable = $false
      compatible = $false
      detail = "working directory does not exist: $WorkingDirectory"
      source = 'filesystem-probe'
    }
  }
  if ($FilesystemPermission -ne 'scoped-write') {
    return [pscustomobject]@{
      writable = $true
      compatible = $true
      detail = 'write probe not required'
      source = 'filesystem-probe'
    }
  }
  $probe = Join-Path $WorkingDirectory ('.agenthub-write-probe-' + [guid]::NewGuid().ToString('N'))
  try {
    [IO.File]::WriteAllText($probe, 'probe')
    if (-not (Test-Path -LiteralPath $probe)) {
      throw 'probe file was not created'
    }
    Remove-Item -LiteralPath $probe -Force
    return [pscustomobject]@{
      writable = $true
      compatible = $true
      detail = 'write probe succeeded'
      source = 'filesystem-probe'
    }
  } catch {
    if (Test-Path -LiteralPath $probe) {
      Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    }
    return [pscustomobject]@{
      writable = $false
      compatible = $false
      detail = $_.Exception.Message
      source = 'filesystem-probe'
    }
  }
}

function Get-ProjectEnvironmentDiscovery {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [hashtable]$Contract = $null
  )

  $ecosystems = [System.Collections.Generic.List[string]]::new()
  $packageManagers = [System.Collections.Generic.List[object]]::new()
  $dependencies = $null
  $verificationTools = [ordered]@{}

  # 1. Docker / Compose Discovery
  $composeCandidates = @(
    'docker-compose.yml', 'docker-compose.yaml',
    'compose.yml', 'compose.yaml',
    'docker/docker-compose.yml', 'docker/compose.yml',
    'infrastructure/docker-compose.yml'
  )
  $detectedCompose = $null
  if (Test-Path -LiteralPath $WorkingDirectory) {
    foreach ($candidate in $composeCandidates) {
      $fullPath = Join-Path $WorkingDirectory $candidate
      if (Test-Path -LiteralPath $fullPath) {
        $detectedCompose = $candidate.Replace('\', '/')
        break
      }
    }
  }
  $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
  $dockerAvailable = [bool]$dockerCommand
  $dockerDiscovery = [pscustomobject]@{
    compose_detected = [bool]$detectedCompose
    compose_file = $detectedCompose
    docker_available = $dockerAvailable
  }

  # 2. Node.js Discovery
  $nodePackageFiles = @()
  if (Test-Path -LiteralPath $WorkingDirectory) {
    $rootPkg = Join-Path $WorkingDirectory 'package.json'
    if (Test-Path -LiteralPath $rootPkg) { $nodePackageFiles += $rootPkg }
    foreach ($sub in @('frontend', 'client', 'app', 'web', 'ui')) {
      $subPkg = Join-Path (Join-Path $WorkingDirectory $sub) 'package.json'
      if (Test-Path -LiteralPath $subPkg) { $nodePackageFiles += $subPkg }
    }
  }

  $hasNode = ($nodePackageFiles.Count -gt 0)
  if ($hasNode) {
    if (-not ($ecosystems -contains 'node')) { $ecosystems.Add('node') }
    foreach ($pkgFile in $nodePackageFiles) {
      $pkgDir = Split-Path $pkgFile -Parent
      $relDir = [IO.Path]::GetRelativePath($WorkingDirectory, $pkgDir).Replace('\', '/')
      if ($relDir -eq '.') { $relDir = '' }
      
      $pnpmLock = Join-Path $pkgDir 'pnpm-lock.yaml'
      $yarnLock = Join-Path $pkgDir 'yarn.lock'
      $npmLock = Join-Path $pkgDir 'package-lock.json'
      $bunLock = Join-Path $pkgDir 'bun.lockb'
      if (-not (Test-Path -LiteralPath $bunLock)) { $bunLock = Join-Path $pkgDir 'bun.lock' }

      $pmType = 'npm'
      $pmSource = 'package.json (default)'
      if (Test-Path -LiteralPath $pnpmLock) {
        $pmType = 'pnpm'
        $pmSource = if ($relDir) { "$relDir/pnpm-lock.yaml" } else { 'pnpm-lock.yaml' }
      } elseif (Test-Path -LiteralPath $yarnLock) {
        $pmType = 'yarn'
        $pmSource = if ($relDir) { "$relDir/yarn.lock" } else { 'yarn.lock' }
      } elseif (Test-Path -LiteralPath $npmLock) {
        $pmType = 'npm'
        $pmSource = if ($relDir) { "$relDir/package-lock.json" } else { 'package-lock.json' }
      } elseif (Test-Path -LiteralPath $bunLock) {
        $pmType = 'bun'
        $pmSource = if ($relDir) { "$relDir/" + (Split-Path $bunLock -Leaf) } else { Split-Path $bunLock -Leaf }
      }

      $pmCmdAvailable = [bool](Get-Command $pmType -ErrorAction SilentlyContinue)
      $packageManagers.Add([pscustomobject]@{
        ecosystem = 'node'
        type = $pmType
        source = $pmSource
        command_available = $pmCmdAvailable
        directory = if ($relDir) { $relDir } else { '.' }
      })

      # Dependency state for this node package
      $nodeModules = Join-Path $pkgDir 'node_modules'
      $hasModules = (Test-Path -LiteralPath $nodeModules) -and ((Get-ChildItem -LiteralPath $nodeModules -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
      $relModules = if ($relDir) { "$relDir/node_modules" } else { 'node_modules' }
      if (-not $dependencies -or $dependencies.status -eq 'READY') {
        $dependencies = [pscustomobject]@{
          status = if ($hasModules) { 'READY' } else { 'MISSING' }
          path = $relModules
          detail = if ($hasModules) { "dependencies present at $relModules" } else { "dependencies missing at $relModules" }
          source = if ($relDir) { "$relDir/package.json" } else { 'package.json' }
        }
      }

      # Check Playwright & npm scripts
      $pkgContent = $null
      try { $pkgContent = Get-Content -Raw -LiteralPath $pkgFile | ConvertFrom-Json -AsHashtable } catch {}
      $playwrightDeclared = $false
      $playwrightConfig = $null
      foreach ($pwCfg in @('playwright.config.ts', 'playwright.config.js', 'playwright.config.mjs', 'playwright.config.cjs')) {
        $cfgPath = Join-Path $pkgDir $pwCfg
        if (Test-Path -LiteralPath $cfgPath) {
          $playwrightDeclared = $true
          $playwrightConfig = if ($relDir) { "$relDir/$pwCfg" } else { $pwCfg }
          break
        }
      }
      if (-not $playwrightDeclared -and $pkgContent -is [hashtable]) {
        $allDeps = [System.Collections.Generic.List[string]]::new()
        if ($pkgContent.ContainsKey('dependencies') -and $pkgContent['dependencies'] -is [hashtable]) {
          foreach ($k in $pkgContent['dependencies'].Keys) { $allDeps.Add([string]$k) }
        }
        if ($pkgContent.ContainsKey('devDependencies') -and $pkgContent['devDependencies'] -is [hashtable]) {
          foreach ($k in $pkgContent['devDependencies'].Keys) { $allDeps.Add([string]$k) }
        }
        if ($allDeps -contains '@playwright/test' -or $allDeps -contains 'playwright') {
          $playwrightDeclared = $true
          $playwrightConfig = if ($relDir) { "$relDir/package.json" } else { 'package.json' }
        }
      }
      if ($playwrightDeclared) {
        $pwBin = Join-Path (Join-Path $pkgDir 'node_modules') '.bin/playwright'
        $pwBinCmd = Join-Path (Join-Path $pkgDir 'node_modules') '.bin/playwright.cmd'
        $pwAvailable = [bool](Get-Command playwright -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath $pwBin) -or (Test-Path -LiteralPath $pwBinCmd)
        $verificationTools['playwright'] = [pscustomobject]@{
          declared = $true
          executable_available = $pwAvailable
          source = $playwrightConfig
        }
      }

      $testScript = $false
      if ($pkgContent -is [hashtable] -and $pkgContent.ContainsKey('scripts') -and $pkgContent['scripts'] -is [hashtable]) {
        $scriptsTable = $pkgContent['scripts']
        if ($scriptsTable.ContainsKey('test') -and $scriptsTable['test'] -and ($scriptsTable['test'] -notmatch 'no test specified')) {
          $testScript = $true
        }
      }
      $verificationTools['npm_scripts'] = [pscustomobject]@{
        declared = $true
        test_script = $testScript
        source = if ($relDir) { "$relDir/package.json" } else { 'package.json' }
      }
    }
  }

  # 3. Java / Maven Discovery
  $mavenFiles = @()
  if (Test-Path -LiteralPath $WorkingDirectory) {
    $rootPom = Join-Path $WorkingDirectory 'pom.xml'
    if (Test-Path -LiteralPath $rootPom) { $mavenFiles += $rootPom }
    foreach ($sub in @('backend', 'server', 'app', 'service', 'api')) {
      $subPom = Join-Path (Join-Path $WorkingDirectory $sub) 'pom.xml'
      if (Test-Path -LiteralPath $subPom) { $mavenFiles += $subPom }
    }
  }
  if ($mavenFiles.Count -gt 0) {
    if (-not ($ecosystems -contains 'maven')) { $ecosystems.Add('maven') }
    foreach ($pomFile in $mavenFiles) {
      $pomDir = Split-Path $pomFile -Parent
      $relDir = [IO.Path]::GetRelativePath($WorkingDirectory, $pomDir).Replace('\', '/')
      if ($relDir -eq '.') { $relDir = '' }
      $mvnw = Join-Path $pomDir 'mvnw'
      $mvnwCmd = Join-Path $pomDir 'mvnw.cmd'
      $hasMvnw = (Test-Path -LiteralPath $mvnw) -or (Test-Path -LiteralPath $mvnwCmd)
      $mvnAvailable = $hasMvnw -or [bool](Get-Command mvn -ErrorAction SilentlyContinue)
      $packageManagers.Add([pscustomobject]@{
        ecosystem = 'maven'
        type = if ($hasMvnw) { 'mvnw' } else { 'maven' }
        source = if ($hasMvnw) { if ($relDir) { "$relDir/mvnw" } else { 'mvnw' } } else { if ($relDir) { "$relDir/pom.xml" } else { 'pom.xml' } }
        command_available = $mvnAvailable
        directory = if ($relDir) { $relDir } else { '.' }
      })
      if ($hasMvnw) {
        $verificationTools['maven_wrapper'] = [pscustomobject]@{
          declared = $true
          executable_available = $true
          source = if ($relDir) { "$relDir/mvnw" } else { 'mvnw' }
        }
      }
    }
  }

  # 4. Java / Gradle Discovery
  $gradleFiles = @()
  if (Test-Path -LiteralPath $WorkingDirectory) {
    foreach ($gFile in @('build.gradle', 'build.gradle.kts', 'gradlew', 'gradlew.bat')) {
      $p = Join-Path $WorkingDirectory $gFile
      if (Test-Path -LiteralPath $p) { $gradleFiles += $p }
      foreach ($sub in @('backend', 'server', 'app')) {
        $subG = Join-Path (Join-Path $WorkingDirectory $sub) $gFile
        if (Test-Path -LiteralPath $subG) { $gradleFiles += $subG }
      }
    }
  }
  if ($gradleFiles.Count -gt 0) {
    if (-not ($ecosystems -contains 'gradle')) { $ecosystems.Add('gradle') }
    $gradlew = Join-Path $WorkingDirectory 'gradlew'
    $gradlewBat = Join-Path $WorkingDirectory 'gradlew.bat'
    $hasGradlew = (Test-Path -LiteralPath $gradlew) -or (Test-Path -LiteralPath $gradlewBat)
    $gradleAvailable = $hasGradlew -or [bool](Get-Command gradle -ErrorAction SilentlyContinue)
    $packageManagers.Add([pscustomobject]@{
      ecosystem = 'gradle'
      type = if ($hasGradlew) { 'gradlew' } else { 'gradle' }
      source = if ($hasGradlew) { 'gradlew' } else { 'build.gradle' }
      command_available = $gradleAvailable
      directory = '.'
    })
    if ($hasGradlew) {
      $verificationTools['gradle_wrapper'] = [pscustomobject]@{
        declared = $true
        executable_available = $true
        source = 'gradlew'
      }
    }
  }

  # 5. Python Discovery
  $pyFiles = @('pyproject.toml', 'requirements.txt', 'Pipfile', 'setup.py')
  $detectedPy = $null
  if (Test-Path -LiteralPath $WorkingDirectory) {
    foreach ($pf in $pyFiles) {
      $p = Join-Path $WorkingDirectory $pf
      if (Test-Path -LiteralPath $p) { $detectedPy = $pf; break }
    }
  }
  if ($detectedPy) {
    if (-not ($ecosystems -contains 'python')) { $ecosystems.Add('python') }
    $pyType = 'pip'
    if (Test-Path -LiteralPath (Join-Path $WorkingDirectory 'poetry.lock')) { $pyType = 'poetry' }
    elseif (Test-Path -LiteralPath (Join-Path $WorkingDirectory 'Pipfile.lock')) { $pyType = 'pipenv' }
    $pyCmdAvailable = [bool](Get-Command $pyType -ErrorAction SilentlyContinue) -or [bool](Get-Command python -ErrorAction SilentlyContinue)
    $packageManagers.Add([pscustomobject]@{
      ecosystem = 'python'
      type = $pyType
      source = $detectedPy
      command_available = $pyCmdAvailable
      directory = '.'
    })
    if (-not $dependencies) {
      $venv = Join-Path $WorkingDirectory '.venv'
      if (-not (Test-Path -LiteralPath $venv)) { $venv = Join-Path $WorkingDirectory 'venv' }
      $hasVenv = Test-Path -LiteralPath $venv
      $dependencies = [pscustomobject]@{
        status = if ($hasVenv) { 'READY' } else { 'MISSING' }
        path = if ($hasVenv) { [IO.Path]::GetRelativePath($WorkingDirectory, $venv).Replace('\', '/') } else { '.venv' }
        detail = if ($hasVenv) { 'virtual environment present' } else { 'virtual environment missing' }
        source = $detectedPy
      }
    }
  }

  # 6. .NET Discovery
  $dotnetFiles = @()
  if (Test-Path -LiteralPath $WorkingDirectory) {
    $dotnetFiles = @(Get-ChildItem -LiteralPath $WorkingDirectory -Filter '*.csproj' -File -ErrorAction SilentlyContinue) +
                   @(Get-ChildItem -LiteralPath $WorkingDirectory -Filter '*.sln' -File -ErrorAction SilentlyContinue) +
                   @(Get-ChildItem -LiteralPath $WorkingDirectory -Filter '*.fsproj' -File -ErrorAction SilentlyContinue)
  }
  if ($dotnetFiles.Count -gt 0) {
    if (-not ($ecosystems -contains 'dotnet')) { $ecosystems.Add('dotnet') }
    $dotnetAvailable = [bool](Get-Command dotnet -ErrorAction SilentlyContinue)
    $packageManagers.Add([pscustomobject]@{
      ecosystem = 'dotnet'
      type = 'dotnet'
      source = $dotnetFiles[0].Name
      command_available = $dotnetAvailable
      directory = '.'
    })
  }

  # 7. PowerShell Discovery
  $psFiles = @()
  $hasTests = $false
  if (Test-Path -LiteralPath $WorkingDirectory) {
    $psFiles = @(Get-ChildItem -LiteralPath $WorkingDirectory -Filter '*.psd1' -File -ErrorAction SilentlyContinue) +
               @(Get-ChildItem -LiteralPath $WorkingDirectory -Filter '*.psm1' -File -ErrorAction SilentlyContinue)
    $hasTests = (Test-Path -LiteralPath (Join-Path $WorkingDirectory 'tests')) -and ((Get-ChildItem -LiteralPath (Join-Path $WorkingDirectory 'tests') -Filter '*.tests.ps1' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
  }
  if ($psFiles.Count -gt 0 -or $hasTests) {
    if (-not ($ecosystems -contains 'powershell')) { $ecosystems.Add('powershell') }
    $pwshAvailable = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
    $packageManagers.Add([pscustomobject]@{
      ecosystem = 'powershell'
      type = 'pwsh'
      source = if ($psFiles.Count -gt 0) { $psFiles[0].Name } else { 'tests' }
      command_available = $pwshAvailable
      directory = '.'
    })
    if ($hasTests) {
      $verificationTools['pester'] = [pscustomobject]@{
        declared = $true
        executable_available = $pwshAvailable
        source = 'tests/*.tests.ps1'
      }
    }
  }

  # Default fallbacks if nothing detected
  if ($ecosystems.Count -eq 0) {
    $ecosystems.Add('unknown')
  }
  $primaryPm = if ($packageManagers.Count -gt 0) {
    $packageManagers[0]
  } else {
    [pscustomobject]@{
      ecosystem = 'unknown'
      type = 'unknown'
      source = $null
      command_available = $false
      directory = '.'
    }
  }
  if (-not $dependencies) {
    $dependencies = [pscustomobject]@{
      status = if ($ecosystems -contains 'unknown') { 'UNKNOWN' } else { 'READY' }
      path = $null
      detail = if ($ecosystems -contains 'unknown') { 'no supported package manager detected' } else { 'no explicit dependency directory required' }
      source = $null
    }
  }

  # Ensure standard verification tool keys exist
  if (-not $verificationTools.Contains('playwright')) {
    $verificationTools['playwright'] = [pscustomobject]@{ declared = $false; executable_available = $false; source = $null }
  }
  if (-not $verificationTools.Contains('maven_wrapper')) {
    $verificationTools['maven_wrapper'] = [pscustomobject]@{ declared = $false; executable_available = $false; source = $null }
  }
  if (-not $verificationTools.Contains('gradle_wrapper')) {
    $verificationTools['gradle_wrapper'] = [pscustomobject]@{ declared = $false; executable_available = $false; source = $null }
  }
  if (-not $verificationTools.Contains('npm_scripts')) {
    $verificationTools['npm_scripts'] = [pscustomobject]@{ declared = $false; test_script = $false; source = $null }
  }

  # Sandbox capability probe
  $filesystemPermission = if ($Contract -and ($Contract -is [hashtable]) -and $Contract.ContainsKey('permissions') -and ($Contract['permissions'] -is [hashtable]) -and $Contract['permissions'].ContainsKey('filesystem')) {
    [string]$Contract['permissions']['filesystem']
  } else {
    'scoped-write'
  }
  $sandbox = Test-EnvironmentSandboxCapability -WorkingDirectory $WorkingDirectory -FilesystemPermission $filesystemPermission

  [pscustomobject]@{
    ecosystems = @($ecosystems)
    package_manager = $primaryPm
    package_managers = @($packageManagers)
    dependencies = $dependencies
    docker = $dockerDiscovery
    verification_tools = [pscustomobject]$verificationTools
    sandbox = $sandbox
  }
}

function Resolve-InferredEnvironmentDeclaration {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Contract,
    [Parameter(Mandatory)][string]$WorkingDirectory,
    $Discovery = $null
  )

  if (-not $Discovery) {
    $Discovery = Get-ProjectEnvironmentDiscovery -WorkingDirectory $WorkingDirectory -Contract $Contract
  }

  $explicitEnv = if ($Contract.ContainsKey('environment') -and $Contract.environment -is [hashtable]) {
    $Contract.environment
  } else {
    @{ }
  }

  # 1. Required commands
  $requiredCommands = if ($explicitEnv.ContainsKey('required_commands')) {
    @($explicitEnv.required_commands)
  } else {
    $inferredCmds = [System.Collections.Generic.List[object]]::new()
    if ($Discovery.ecosystems -contains 'node') {
      $inferredCmds.Add(@{ name = 'node'; required = $true })
      if ($Discovery.package_manager.type -ne 'unknown' -and $Discovery.package_manager.type -ne 'node') {
        $inferredCmds.Add(@{ name = $Discovery.package_manager.type; required = $true })
      }
    }
    if ($Discovery.ecosystems -contains 'maven' -and -not ($Discovery.ecosystems -contains 'node')) {
      if ($Discovery.package_manager.type -eq 'mvnw') {
        # wrapper resolvable via file
      } else {
        $inferredCmds.Add(@{ name = 'mvn'; required = $true })
      }
    }
    if ($Discovery.ecosystems -contains 'gradle' -and -not ($Discovery.ecosystems -contains 'node')) {
      if ($Discovery.package_manager.type -ne 'gradlew') {
        $inferredCmds.Add(@{ name = 'gradle'; required = $true })
      }
    }
    if ($Discovery.ecosystems -contains 'python') {
      $inferredCmds.Add(@{ name = 'python'; required = $true })
    }
    if ($Discovery.ecosystems -contains 'dotnet') {
      $inferredCmds.Add(@{ name = 'dotnet'; required = $true })
    }
    if ($Discovery.ecosystems -contains 'powershell' -and $Discovery.ecosystems.Count -eq 1) {
      $inferredCmds.Add(@{ name = 'pwsh'; required = $true })
    }
    @($inferredCmds)
  }

  # 2. Dependencies
  $dependencies = if ($explicitEnv.ContainsKey('dependencies')) {
    @($explicitEnv.dependencies)
  } else {
    $inferredDeps = [System.Collections.Generic.List[object]]::new()
    if ($Discovery.dependencies -and $Discovery.dependencies.path) {
      $inferredDeps.Add(@{
        name = 'project-dependencies'
        path = $Discovery.dependencies.path
        required = $true
      })
    }
    # If there are multiple package managers (e.g. frontend/node_modules in a multi-project repo)
    foreach ($pm in @($Discovery.package_managers)) {
      if ($pm.ecosystem -eq 'node' -and $pm.directory -ne '.') {
        $subMod = "$($pm.directory)/node_modules"
        if (@($inferredDeps | Where-Object { $_.path -eq $subMod }).Count -eq 0) {
          $inferredDeps.Add(@{
            name = "$($pm.directory)-dependencies"
            path = $subMod
            required = $true
          })
        }
      }
    }
    @($inferredDeps)
  }

  # 3. Verification commands
  $verificationCommands = if ($explicitEnv.ContainsKey('verification_commands')) {
    @($explicitEnv.verification_commands)
  } else {
    $inferredVer = [System.Collections.Generic.List[object]]::new()
    if ($Discovery.verification_tools.playwright.declared) {
      # If task verification requires e2e, require playwright
      $e2eRequired = ($Contract.ContainsKey('verification') -and $Contract.verification -is [hashtable] -and $Contract.verification.ContainsKey('e2e') -and $Contract.verification.e2e -ne 'NOT_APPLICABLE')
      if ($e2eRequired) {
        $inferredVer.Add(@{
          name = 'playwright'
          file = 'npx'
          required = $true
        })
      }
    }
    @($inferredVer)
  }

  # 4. Services (Do NOT automatically start arbitrary services merely because Compose exists)
  $services = if ($explicitEnv.ContainsKey('services')) {
    @($explicitEnv.services)
  } else {
    @()
  }

  # 5. Preparation
  $preparation = if ($explicitEnv.ContainsKey('preparation') -and $explicitEnv.preparation -is [hashtable]) {
    $explicitEnv.preparation
  } else {
    @{ allowed = $false; actions = @() }
  }

  @{
    required_commands = @($requiredCommands)
    dependencies = @($dependencies)
    services = @($services)
    verification_commands = @($verificationCommands)
    preparation = $preparation
    discovery = $Discovery
  }
}

Export-ModuleMember -Function Test-EnvironmentSandboxCapability, Get-ProjectEnvironmentDiscovery, Resolve-InferredEnvironmentDeclaration
