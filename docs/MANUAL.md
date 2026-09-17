# Manual de AgentHub

AgentHub es una capa local de control para tareas de desarrollo asistidas por agentes. Su función es delimitar una tarea con un contrato BDD v2, aislarla en un worktree, exigir presupuesto explícito para una ejecución real y dejar evidencia para revisión humana.

No es un sistema de entrega autónoma: una persona revisa los cambios, decide si los integra y controla cualquier gasto de modelo.

## Requisitos y comprobación inicial

En Windows, desde un clon del repositorio:

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 doctor
pwsh -NoProfile -File .\scripts\test.ps1
```

`doctor` no inicia inferencia. Informa de PowerShell, Git, disponibilidad de la CLI, capacidad anunciada de sandbox, instalación local y baseline de guardrails.

## Contrato BDD v2

Cada tarea se describe en JSON. El contrato debe identificar el repositorio, el objetivo, el rol `implementer`, el motor, la rama, los archivos permitidos, las exclusiones, permisos y comprobaciones. Valídalo antes de cualquier ejecución:

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 validate .\TASK_CONTRACT.json
```

Los campos `scope.allowed` son la frontera de escritura. Los cambios válidos se clasifican como implementación, prueba o documentación. La implementación no se limita a una carpeta global como `src`; una modificación permitida que no sea prueba ni documentación cuenta como implementación.

## Consultar una tarea sin mutarla

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 status .\TASK_CONTRACT.json
```

La salida muestra ID de tarea, estado, rol, motor, repositorio, contexto acotado y presupuesto si existe. `status` valida el contrato, pero no lo modifica, no crea worktrees y no llama a un modelo.

## Preflight y presupuesto

`preflight` valida el contrato y comprueba el adaptador, la CLI y el sandbox sin pedir trabajo al modelo:

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 preflight .\TASK_CONTRACT.json
```

Una ejecución real necesita autorización explícita. Los presupuestos son locales, están ignorados por Git y se asocian al ID de tarea mediante una ruta derivada de SHA-256 más un `task_id` interno. Esto impide que una tarea consuma, reinicie o reutilice el presupuesto de otra.

Un presupuesto agotado nunca se repone automáticamente. El archivo global heredado se conserva como evidencia histórica y no autoriza tareas nuevas.

## Ejecutar y revisar

```powershell
pwsh -NoProfile -File .\scripts\agenthub.ps1 run .\TASK_CONTRACT.json -EngineExecutable <ruta-a-codex.exe>
```

`run` crea un worktree, ensambla contexto permitido, consume el presupuesto de forma atómica antes de iniciar el proceso, verifica alcance y pruebas configuradas, compara guardrails y escribe evidencia. El estado final esperado es `READY_FOR_HUMAN`; nunca implica push, merge o release automáticos.

Revisa siempre el diff, la evidencia y la batería determinista antes de integrar:

```powershell
pwsh -NoProfile -File .\scripts\test.ps1
```

## Estados y resultados

El contrato progresa por `READY`, `CLAIMED`, `IMPLEMENTING`, `VERIFYING`, `REVIEWING` y `READY_FOR_HUMAN`. Un proceso puede terminar correctamente y aun así fallar si no hay progreso significativo, el alcance es inválido, fallan pruebas o aparecen nuevos guardrails. Esa distinción es intencional: el código de salida del proveedor no sustituye la verificación independiente.

## Límites actuales

- Windows es la plataforma soportada en esta alpha.
- Codex es el único runtime probado.
- El CLI y el sandbox pueden variar por versión y entorno.
- La orquestación de GitHub, otros proveedores, merge y release permanecen bajo control humano.
- Las pruebas y CI son deterministas y no realizan inferencia.

Consulta [DOGFOODING.md](DOGFOODING.md) para los resultados históricos y [COMMERCIALIZATION.md](COMMERCIALIZATION.md) para una propuesta inicial de producto.
