# Agentic Development Platform

Una plataforma portable para gobernar desarrollo asistido por agentes (Codex, Gemini u otros) sin acoplar el proceso a un proveedor concreto. Incluye políticas, contratos BDD v2, plantillas, validadores de PowerShell y pruebas deterministas.

> Estado: base de automatización y gobernanza local. Revísala y adapta la política de infraestructura y seguridad a cada organización antes de usarla en producción.

## Qué incluye

- Políticas globales versionadas para Git, seguridad, pruebas, CI/CD, observabilidad e infraestructura.
- Contrato BDD v2 validable, estados canónicos, roles y evidencias reproducibles.
- `AgentHub`: ejecutor basado en worktrees con comprobaciones de permisos, alcance, presupuesto y evidencia.
- Adaptador de Codex que descubre los modos admitidos por la CLI y diferencia entre `cli_accepted` y `sandbox_operational`.
- Plantillas para `AGENTS.md`, ADRs, issues y pull requests.
- Pruebas PowerShell sin dependencias de red ni inferencia de modelos.

## Requisitos

- Windows PowerShell 5.1+ o PowerShell 7+
- Git
- Para las funciones de Codex: Codex CLI autenticado y disponible en `PATH`

## Primeros pasos

```powershell
git clone https://github.com/azfalot/agentic-development-platform.git
Set-Location agentic-development-platform

# Ejecutar la batería de pruebas deterministas
Get-ChildItem .\tests\*.tests.ps1 | ForEach-Object { & $_.FullName }
```

Valida un contrato BDD v2:

```powershell
powershell -NoProfile -File .\scripts\agenthub.ps1 validate C:\ruta\a\contrato.json
```

Consulta la preparación local sin iniciar una tarea de IA:

```powershell
powershell -NoProfile -File .\scripts\agenthub.ps1 preflight C:\ruta\a\contrato.json
```

El preflight comprueba dos cosas separadas:

- `cli_accepted`: la CLI reconoce `workspace-write`.
- `sandbox_operational`: Codex puede iniciar un proceso hijo en el sandbox restringido. Una CLI aceptada no prueba que el sandbox funcione.

## Estructura

```text
policies/    Políticas modulares de desarrollo
bdd/         Contratos, estados, roles y evidencia BDD v2
scripts/     Validadores, sincronización y AgentHub
skills/      Instrucciones reutilizables para flujos de agentes
templates/   Plantillas de repositorio y entrega
tests/       Verificación determinista de los componentes
evidence/    Diagnósticos reproducibles, sin credenciales
```

## Seguridad y configuración local

Este repositorio no contiene credenciales. La política de PostgreSQL usa marcadores como `<LOCAL_POSTGRES_PASSWORD>`; define los secretos en tu entorno o almacén de secretos local, nunca en Git.

Antes de activar ejecución real de un agente, configura explícitamente el presupuesto de ejecución y revisa el contrato, la rama y el alcance de archivos. Las pruebas y los comandos `validate`, `preflight` y `-DryRun` no requieren invocar un modelo.

## Estado del sandbox de Codex en Windows

El diagnóstico incluido en [`evidence/windows-sandbox-diagnosis-20260916.md`](evidence/windows-sandbox-diagnosis-20260916.md) documenta una incidencia reproducible de `workspace-write` en Codex CLI 0.146.0 sobre Windows 10. No se recomienda sortearla usando acceso total; actualiza Codex y ejecuta de nuevo el preflight no inferencial.

## Licencia

MIT. Consulta [LICENSE](LICENSE).
