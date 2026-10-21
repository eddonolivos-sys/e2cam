# Registro de Pases de Batuta

Historial de traspasos entre roles. Todos los roles añaden entradas al final; ninguna entrada se edita ni se borra. La última entrada indica quién tiene la batuta.

Formato: una entrada por línea, con los campos separados por " | ".

Pase | AAAA-MM-DD HH:MM | Origen -> Destino | Fase | Resumen

Este formato de una línea es deliberado: el analizador procesa el registro para calcular métricas DORA adaptadas (lead time por fase, frecuencia de entrega, tasa de re-trabajo, tiempo de recuperación). Mantener el formato es lo que hace posibles esas métricas.

Roles válidos como Origen y Destino: Usuario, Planificador, Ejecutor, Documentador, Analizador. Origen y Destino pueden coincidir en continuaciones por límite de contexto (por ejemplo, Ejecutor -> Ejecutor).

Valores de Fase: FASE-NN, Descubrimiento, Documentacion, Analisis.

<!-- Ejemplo de referencia:

1 | 2026-01-15 10:30 | Planificador -> Ejecutor | FASE-01 | Prompt de ejecucion emitido: nucleo de dominio de tareas con TDD y dos escenarios BDD.
2 | 2026-01-15 16:45 | Ejecutor -> Planificador | FASE-01 | Retorno entregado: DoD cumplido, metricas dentro de umbrales, cobertura 86 por ciento.
3 | 2026-01-15 17:10 | Planificador -> Ejecutor | FASE-02 | FASE-01 aprobada; prompt de FASE-02 emitido (persistencia real).
-->

<!-- Las entradas reales comienzan debajo de esta línea. -->

1 | 2026-10-21 14:42 | Usuario -> Planificador | Descubrimiento | Objetivo y restricciones recibidos; Design Doc v1 y ADR-001 a ADR-009 redactados por delegacion del usuario; escenarios de FASE-01 pendientes de validacion.
2 | 2026-10-21 14:53 | Planificador -> Ejecutor | FASE-01 | Escenarios validados por el usuario; prompt de ejecucion emitido: esqueleto andante camara-membrana-pantalla con solver CPU, Three.js, cadena de calidad y Docker; 13 escenarios BDD.
