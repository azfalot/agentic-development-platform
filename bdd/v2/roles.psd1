@{
  architect = @{ capabilities = @('design', 'scope', 'adr'); permissions = @{ filesystem = 'read-only'; git_write = $false; github_write = $false; merge = $false; production = 'denied' } }
  implementer = @{ capabilities = @('implement', 'unit-test', 'integration-test'); permissions = @{ filesystem = 'scoped-write'; git_write = $true; github_write = $true; merge = $false; production = 'denied' } }
  reviewer = @{ capabilities = @('review', 'evidence-assessment'); permissions = @{ filesystem = 'read-only'; git_write = $false; github_write = $true; merge = $false; production = 'denied' } }
  researcher = @{ capabilities = @('research', 'analysis'); permissions = @{ filesystem = 'read-only'; git_write = $false; github_write = $false; merge = $false; production = 'denied' } }
  validator = @{ capabilities = @('build', 'lint', 'test', 'guardrail'); permissions = @{ filesystem = 'read-only'; git_write = $false; github_write = $false; merge = $false; production = 'denied' } }
  release = @{ capabilities = @('release-coordination', 'release-verification'); permissions = @{ filesystem = 'read-only'; git_write = $false; github_write = $true; merge = $false; production = 'approval-required' } }
}
