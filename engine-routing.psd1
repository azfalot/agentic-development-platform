@{
  implementer = @{ engines = @('codex') }
  adapters = @{
    codex = @{
      module = 'CodexAdapter.psm1'
      resolve_function = 'Resolve-CodexExecutionSpecification'
      test_function = 'Test-CodexExecutionSpecification'
      default_executable = 'codex'
    }
  }
}
