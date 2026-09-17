# Resultados de dogfooding

Estas ejecuciones midieron AgentHub con tareas pequeñas y presupuestos de una sola invocación. Son evidencia de ingeniería, no garantía de comportamiento en otros entornos o versiones de CLI.

| Ejecución | Resultado | Hallazgo | Acción tomada |
| --- | --- | --- | --- |
| DOGFOODING_01 | Falló tras proceso con salida `0` | El clasificador asumía que implementación significaba `src/**`; una modificación válida en `scripts/` quedó como falta de progreso. | Se añadió clasificación dependiente del contrato y pruebas de regresión. La evidencia original permanece fallida. |
| DOGFOODING_02, primer intento | Detenida antes de dispatch | El presupuesto era global al repositorio y el agotado de la tarea anterior bloqueaba a una tarea distinta. | Se migró a presupuestos por ID de tarea con identidad validada y consumo atómico. |
| DOGFOODING_02, ejecución reanudada | Detenida antes de verificación | La implementación de `status` quedó acotada y sus pruebas pasan, pero la cuenta alcanzó el límite de uso antes de la verificación de AgentHub. | No hubo reintento automático. Se validó el diff y la batería determinista localmente antes de publicar el código. |

## Métricas observadas

- DOGFOODING_01: 1 invocación, 58.331 tokens informados, 234.457 ms.
- DOGFOODING_02 reanudado: 1 invocación, 57.218 tokens informados, 234.281 ms, 33.158 bytes de contexto acotado en siete archivos.

Los límites de uso son una dependencia operativa externa. Antes de una tarea real, confirma cuota disponible, presupuesto de la tarea y el resultado de `preflight`.
