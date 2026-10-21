# Plantilla: Prompt de Documentación

<!--
Instrucciones para el planificador:
- Completa esta plantilla al finalizar las fases funcionales y guarda el
  resultado en .flow/state/prompt_documentacion.md.
- La procesará el documentador (.flow/roles/documentador.md) o, en su defecto,
  el ejecutor en modo documentación.
- Elimina estos comentarios al generar el prompt real.
-->

## Tipo de documentación

[Técnica / Usuario / Ambas]

## Alcance

[Qué partes del sistema se documentan y qué queda explícitamente fuera.]

## Secciones obligatorias

1. Resumen ejecutivo: qué es el sistema y qué problema resuelve.
2. Arquitectura en modelo C4: nivel 1 (Contexto) y nivel 2 (Contenedores) en
   texto, con diagramas Mermaid cuando el formato lo permita; nivel 3
   (Componentes) si aporta claridad.
3. Decisiones clave: resumen de los ADR de .flow/state/decisiones.md, citando
   identificadores ADR-NNN y estado.
4. Stack tecnológico y versiones.
5. Estructura del proyecto: árbol de carpetas comentado.
6. Guía de instalación y ejecución: requisitos, pasos, verificación.
7. Guía de uso: desarrolladores y/o usuario final según el tipo solicitado.
8. Endpoints o API pública (si aplica): ruta, método, parámetros, respuestas, errores.
9. Métricas objetivo y resultados: fórmulas usadas en el plan (inestabilidad
   I = Ce / (Ca + Ce); abstracción A = Na / Nc; distancia D = |A + I - 1|;
   Amdahl Speedup = 1 / ((1-P) + P/N); entropía H = -sum(p_i * log2(p_i))),
   con su significado, los umbrales fijados y los valores medidos si existen
   (.flow/metrics/, .flow/analisis/); si no existen aún, cómo se verificarán.
10. Diagramas de secuencia de los flujos principales (Mermaid o texto).
11. Índice, referencias cruzadas y ejemplos de uso.

## Formato

- Documentación técnica: Markdown en docs/tech/.
- Documentación de usuario: HTML estático en docs/user/, sin dependencias
  externas. Si se prefiere MkDocs o Sphinx, indicarlo aquí con la
  configuración y los comandos de build esperados.

## Ubicación

- docs/tech/ y docs/user/ (crear las carpetas si no existen).

## Productos esperados

- [Lista de archivos concretos. Ejemplo: docs/tech/index.md,
  docs/tech/arquitectura.md, docs/tech/decisiones.md, docs/tech/api.md,
  docs/tech/metricas.md, docs/user/index.html, docs/user/guia_uso.html]

## Notas adicionales

[Audiencia, tono, idioma, capturas o placeholders, glosario, etc.]

---
Al terminar, escribe tu informe en .flow/state/retorno_ejecutor.md usando la plantilla .flow/prompts/template_retorno.md (indicando Fase: Documentación) y actualiza .flow/state/handoff_log.md.
