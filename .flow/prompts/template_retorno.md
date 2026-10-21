# Plantilla: Informe de Retorno

<!--
Instrucciones para el ejecutor (o el documentador):
- Completa TODAS las secciones y guarda el resultado en
  .flow/state/retorno_ejecutor.md, sobrescribiendo el contenido anterior.
- Si una sección no tiene contenido, escribe "Ninguna" o "No aplica"; no la
  elimines: el planificador evalúa el informe por su estructura completa.
- La aprobación de la fase depende de la sección "Evidencia de DoD" y de las
  métricas reportadas: sin evidencia, un criterio cuenta como no cumplido.
- Recuerda añadir la entrada en .flow/state/handoff_log.md
  (Ejecutor -> Planificador, o Documentador -> Planificador).
- Elimina estos comentarios al redactar el informe real.
-->

## Fase

[Identificador y nombre. Estado: COMPLETADA o PARCIAL (bloqueo).]

## Resumen de lo implementado

[Qué existe ahora que antes no existía, en términos funcionales y técnicos.
Tres a diez líneas; el detalle va en las secciones siguientes.]

## Desviaciones respecto al plan

[Lista. Para cada una: qué se hizo distinto de lo indicado en el prompt, por
qué, y qué impacto tiene. "Ninguna" si no las hubo.]

## Bloqueos o problemas encontrados

[Síntoma observado, causa si se conoce, intentos de resolución, alternativas
propuestas al planificador. "Ninguno" si no los hubo.]

## Decisiones técnicas no previstas

[Decisiones menores tomadas sobre la marcha, con justificación, para que el
planificador las ratifique o revierta (las relevantes acabarán como ADR).
Incluir aquí los tests añadidos por iniciativa propia.]

## Archivos creados / modificados / eliminados

- Creados: [rutas]
- Modificados: [rutas]
- Eliminados: [rutas, con motivo]

## Tests ejecutados y resultados

- Comando para replicar: [ejemplo: pytest tests/ -v]
- Resultado: [N pasan, M fallan. Si hay fallos, pegar la salida de cada error.]
- Cobertura: [porcentaje y comando de medición; "No medida" en caso contrario.]

## Métricas estáticas obtenidas

- Archivo de datos: [.flow/metrics/FASE-NN.json]
- Complejidad ciclomática: [máxima y media; funciones fuera de umbral, si las hay]
- Líneas por método: [máximo observado]
- Acoplamiento por módulo (si hay datos de dependencias): [I, A, D por módulo]
- Veredicto del gate mecánico (python .flow/tools/verificar_fase.py FASE-NN):
  [APTO / NO APTO; pegar la salida completa del script]
- Si hay violaciones: [detalle y análisis de causa; qué se intentó corregir]

## Escenarios BDD implementados y su estado

[Por cada escenario del prompt: nombre, estado (verde / rojo / no implementado)
y, si no está en verde, el motivo. "No aplica" si la fase no tenía escenarios.]

## Evidencia de DoD

[Copiar cada criterio del DoD del prompt y aportar su evidencia concreta:
comando ejecutado y resultado, archivo generado, escenario en verde.]

- Criterio: [texto del criterio] -> Evidencia: [prueba concreta]
- Criterio: [texto del criterio] -> Evidencia: [prueba concreta]

## Notas para el planificador

[Sugerencias, deuda técnica detectada, riesgos para fases siguientes,
oportunidades observadas durante la implementación.]

## ¿Requiere intervención del planificador?

[Sí / No. Si Sí, indicar exactamente qué decisión o aclaración se necesita y
por qué no pudiste resolverlo dentro de tus atribuciones.]
