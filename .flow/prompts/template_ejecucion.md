# Plantilla: Prompt de Ejecución

<!--
Instrucciones para el planificador:
- Completa TODAS las secciones y guarda el resultado en
  .flow/state/prompt_ejecucion.md, sobrescribiendo el contenido anterior.
- Antes de emitir, verifica la Definition of Ready de tu rol (sección 8).
- Describe QUÉ construir y con qué restricciones; nada de pseudocódigo
  literal: el ejecutor es senior. Solo se especifican firmas cuando definen
  un contrato público entre módulos.
- Elimina estos comentarios y el ejemplo del final al generar el prompt real.
-->

## Fase

[Identificador único y nombre. Ejemplo: FASE-01 - Esqueleto andante del servicio de pedidos]

## Objetivo general

[Descripción funcional y técnica de lo que debe existir al terminar la fase:
qué comportamiento se añade y qué contratos expone.]

## Escenarios BDD

[Escenarios Gherkin que actúan como criterios de aceptación ejecutables de la
fase. "No aplica" solo si la fase no tiene comportamiento observable.]

- Escenario 1: [nombre]
  - Dado [contexto inicial]
  - Cuando [acción]
  - Entonces [resultado esperado]
- Escenario 2: [nombre]
  - Dado [contexto]
  - Cuando [acción]
  - Entonces [resultado]

Herramienta BDD: [Behave / Cucumber / pytest-bdd / ninguna: implementar como
tests de aceptación convencionales con estructura Dado-Cuando-Entonces.
Referencia el ADR que decidió la herramienta, si existe.]

## Restricciones de diseño

- Patrones a usar: [patrones concretos, dónde y por qué]
- Principios: [SOLID aplicables, regla de dependencia, ADR vigentes que restringen esta fase]
- Límites de acoplamiento: [qué módulos pueden depender de cuáles; qué queda prohibido]
- Umbrales de métricas estáticas: [I < 0.5 en núcleo, A > 0.5 en módulos estables,
  D < 0.3, complejidad ciclomática < 10, máximo 20 líneas por método;
  ajustar según .flow/tools/metricas_config.yml]

## Tareas detalladas (con TDD)

[Cada tarea sigue el ciclo rojo-verde-refactor. Formato sugerido:]

1. [Tarea]: escribir el test unitario de [comportamiento], verificar que
   falla, implementar el mínimo que lo hace pasar, refactorizar.
2. [Siguiente tarea, mismo ciclo.]
3. [Las tareas deben ser verificables una a una.]

## Tests requeridos

- [Tipos (unitarios, integración, aceptación BDD), casos específicos incluidos
  límites y errores, y cobertura mínima esperada.]

## Métricas a reportar

- Ejecutar las herramientas de análisis estático de .flow/tools/metricas_config.yml
  (por ejemplo: radon cc/mi, dependency-cruiser).
- Guardar el resumen en .flow/metrics/FASE-NN.json siguiendo el esquema
  documentado en la cabecera de .flow/tools/verificar_fase.py.
- Ejecutar el gate mecánico (python .flow/tools/verificar_fase.py FASE-NN) y
  pegar su salida completa en el retorno.
- Reportar además: complejidad ciclomática máxima y media, líneas por método
  máximas, y I, A, D por módulo si hay datos de dependencias.
- Señalar explícitamente cualquier valor fuera de umbral.

## Entorno

- Lenguaje: [lenguaje y versión]
- Framework: [framework y versión, o "ninguno"]
- Versiones: [runtime, librerías clave]
- Gestor de dependencias: [pip, npm, maven, etc., y archivo de manifiesto]

## Estructura de carpetas esperada

[Árbol de carpetas y archivos relevantes para esta fase.]

## Productos de salida

- [Lista explícita de archivos que deben existir al finalizar, incluidos los tests
  y .flow/metrics/FASE-NN.json.]

## DoD de la fase

[Lista binaria: cada criterio se cumple o no se cumple. El retorno debe aportar
evidencia por criterio. Ejemplo de criterios:]

- [ ] Todos los escenarios BDD de esta fase implementados y en verde.
- [ ] Todos los tests unitarios en verde; cobertura >= [X] por ciento en lógica de negocio.
- [ ] Métricas estáticas dentro de umbrales (o desviación justificada y reportada).
- [ ] Estructura de carpetas y contratos conforme a este prompt.
- [ ] .flow/metrics/FASE-NN.json generado y gate mecánico ejecutado, con su
      veredicto incluido en el retorno.
- [ ] Auto-revisión final realizada (sección 6 del rol ejecutor).

## Notas adicionales

[Convenciones de nombres, manejo de errores, logging, idioma de mensajes,
compatibilidad con fases anteriores, etc.]

---
Al terminar, escribe tu informe en .flow/state/retorno_ejecutor.md usando la plantilla .flow/prompts/template_retorno.md y actualiza .flow/state/handoff_log.md.

<!--
EJEMPLO RELLENO (solo referencia; eliminar al generar el prompt real)

## Fase

FASE-01 - Núcleo de dominio de tareas

## Objetivo general

Implementar el modelo de dominio de una aplicación de gestión de tareas:
entidad Tarea con estados (pendiente, en_progreso, completada), reglas de
transición entre estados y los casos de uso CrearTarea y CompletarTarea.
Persistencia en memoria detrás de una interfaz de repositorio.

## Escenarios BDD

- Escenario 1: crear una tarea válida
  - Dado un título "Preparar informe" no vacío
  - Cuando se ejecuta el caso de uso CrearTarea
  - Entonces existe una tarea en estado pendiente con ese título
- Escenario 2: completar una tarea inexistente
  - Dado un repositorio sin tareas
  - Cuando se ejecuta CompletarTarea con un identificador desconocido
  - Entonces se recibe un error de dominio "tarea no encontrada" y nada cambia

Herramienta BDD: ninguna en esta fase; implementar como tests de aceptación
convencionales con estructura Dado-Cuando-Entonces (ver ADR-002).

## Restricciones de diseño

- Patrones a usar: Repository (interfaz en dominio, implementación en
  infraestructura); Factory Method para la creación validada de Tarea.
- Principios: SRP y DIP estrictos; regla de dependencia: todo apunta al dominio.
- Límites de acoplamiento: dominio sin dependencias externas; aplicación
  depende solo de dominio; infraestructura depende solo de dominio.
- Umbrales: D < 0.3 en todos los módulos; complejidad < 10; 20 líneas por método.

## Tareas detalladas (con TDD)

1. Entidad Tarea: escribir tests de transiciones de estado válidas e inválidas,
   verificar que fallan, implementar la entidad, refactorizar.
2. Interfaz RepositorioTareas en dominio: definir contrato y test doble.
3. Casos de uso CrearTarea y CompletarTarea: tests primero con repositorio en
   memoria, luego implementación.
4. Implementación RepositorioMemoria en infraestructura, con sus tests.

## Tests requeridos

- Unitarios: transiciones de estado, creación con datos límite (título vacío,
  título máximo), error al completar tarea inexistente. Cobertura >= 80 por
  ciento en dominio y aplicación.

## Métricas a reportar

- radon cc y mi sobre src/; guardar en .flow/metrics/FASE-01.json; ejecutar el
  gate (python .flow/tools/verificar_fase.py FASE-01) y pegar su veredicto;
  reportar complejidad máxima y media; señalar funciones fuera de umbral.

## Entorno

- Lenguaje: Python 3.12
- Framework: ninguno
- Versiones: pytest 8.x, radon 6.x
- Gestor de dependencias: pip con requirements.txt

## Estructura de carpetas esperada

src/dominio/, src/aplicacion/, src/infraestructura/, tests/unit/, tests/aceptacion/

## Productos de salida

- src/dominio/tarea.py, src/dominio/repositorio_tareas.py
- src/aplicacion/servicios_tarea.py
- src/infraestructura/repositorio_memoria.py
- tests/unit/ y tests/aceptacion/ correspondientes
- requirements.txt actualizado, .flow/metrics/FASE-01.json

## DoD de la fase

- [ ] Escenarios 1 y 2 implementados y en verde.
- [ ] Tests unitarios en verde; cobertura >= 80 por ciento en dominio y aplicación.
- [ ] Complejidad ciclomática < 10 en todas las funciones.
- [ ] Dominio sin imports de infraestructura (verificable por inspección de imports).
- [ ] .flow/metrics/FASE-01.json generado y gate APTO
      (python .flow/tools/verificar_fase.py FASE-01).

## Notas adicionales

- Mensajes de error de dominio en español.
- No introducir dependencias externas en esta fase.
-->
