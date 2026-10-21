# Prompt de ejecución: FASE-01

## Fase

FASE-01: Esqueleto andante (cámara → membrana → pantalla, con Docker).

Fuente de verdad: .flow/state/plan_actual.md (Design Doc v1). Restricciones vigentes: ADR-001 a ADR-009 (.flow/state/decisiones.md).

## Objetivo general

Construir el corte vertical mínimo que valida la arquitectura completa de extremo a extremo:

- la webcam detecta una mano con MediaPipe;
- la proximidad se estima por tamaño aparente;
- se genera una perturbación;
- un solver de CPU de referencia simula la membrana;
- Three.js refracta un mundo de referencia y lo presenta a pantalla completa.

El mismo flujo debe funcionar con el puntero (sin cámara) y con una fuente guionada (pruebas). La aplicación se sirve desde un contenedor Docker con un solo comando. Al terminar, la cadena de calidad (TDD, BDD, ESLint, dependency-cruiser, métricas y gate) debe estar operativa, porque todas las fases siguientes se apoyan en ella. También hay que medir la fracción P de la inferencia en el hilo principal: es la evidencia que decide, por la ley de Amdahl, si FASE-02 migra la sensórica a un Web Worker.

Fuera del alcance de esta fase (no implementar):

- Web Worker;
- FaceDetector (rostro);
- más de 2 manos;
- histéresis, tiempo de gracia, suavizado y asociación de identidades;
- solver de GPU;
- reposo orgánico;
- realce especular obligatorio;
- calibración, lil-gui y persistencia;
- perfiles de calidad.

## Escenarios BDD

Validados por el usuario el 2026-10-21. Los .feature se escriben en español con `# language: es` y conservan el identificador RF en el nombre del escenario.

```gherkin
# language: es
@membrana
Característica: Comportamiento físico de la membrana

  Antecedentes:
    Dado una membrana con los parámetros físicos por defecto

  Escenario: RF-01 La membrana en reposo permanece estable
    Dado que no hay perturbaciones activas
    Cuando transcurren 10 segundos de simulación
    Entonces el desplazamiento máximo es inferior a la tolerancia de reposo
    Y ningún valor del campo de alturas es infinito ni indefinido

  Escenario: RF-02 Una perturbación deforma la membrana en el punto de interacción
    Dado que la membrana está en reposo
    Cuando se aplica una perturbación de contacto en la posición (0.25, 0.75) durante 100 ms
    Entonces el punto de máximo desplazamiento está a menos de un radio de perturbación de (0.25, 0.75)

  Escenario: RF-03 La membrana recupera la calma al cesar la perturbación
    Dado que la membrana ha recibido un contacto sostenido de 1 segundo
    Cuando cesa toda perturbación
    Entonces la energía de la membrana al final de cada ventana de 250 ms es menor que al inicio de esa ventana
    Y en menos de 3 segundos el desplazamiento máximo vuelve a la tolerancia de reposo

  Escenario: RF-04 A mayor intensidad, mayor deformación
    Cuando se aplican por separado dos perturbaciones idénticas salvo en la intensidad, 0.3 y 0.9
    Entonces el desplazamiento máximo producido por la de 0.9 es mayor que el producido por la de 0.3
```

```gherkin
# language: es
@interaccion
Característica: Proximidad e interacción

  Esquema del escenario: RF-10 La proximidad determina la zona y la intensidad
    Dado las referencias de tamaño de mano: influencia 0.10 y contacto 0.20
    Cuando se observa una mano con tamaño aparente <tamaño>
    Entonces la zona de interacción es "<zona>"
    Y la intensidad está en el rango <intensidad>

    Ejemplos:
      | tamaño | zona       | intensidad |
      | 0.05   | ninguna    | [0, 0]     |
      | 0.15   | influencia | (0, 1)     |
      | 0.25   | contacto   | [1, 1]     |

  Escenario: RF-11 La intensidad crece con la proximidad
    Dado las referencias de tamaño de mano: influencia 0.10 y contacto 0.20
    Cuando se observan dos manos con tamaños aparentes 0.12 y 0.18
    Entonces la intensidad de la mano de 0.18 es mayor que la de la mano de 0.12

  Escenario: RF-12 La cámara se comporta como un espejo
    Dado una fuente de cámara con el modo espejo activo
    Cuando se observa una mano en zona de contacto en la posición de imagen (0.2, 0.4)
    Entonces la perturbación se sitúa en la posición de pantalla (0.8, 0.4)

  Escenario: RF-13 Una fuente con profundidad usa la estimación por profundidad
    Dado las referencias de profundidad de mano: influencia 0.60 m y contacto 0.30 m
    Cuando se observa una mano a 0.25 m de profundidad sin tamaño aparente
    Entonces la zona de interacción es "contacto"
    Y si una observación aporta a la vez profundidad y tamaño aparente, prevalece la profundidad
```

```gherkin
# language: es
@sensorica
Característica: Fuentes sensoriales intercambiables

  Escenario: RF-20 Sin cámara la aplicación sigue siendo utilizable con el puntero
    Dado que el acceso a la cámara es denegado o no existe cámara
    Cuando arranca la aplicación
    Entonces se muestra un aviso en español que indica que se usará el puntero
    Y no aparecen errores no controlados en la consola

  Escenario: RF-21 La fuente de puntero produce contactos equivalentes
    Dado la fuente de puntero activa
    Cuando se pulsa el puntero en la posición de pantalla (0.3, 0.6)
    Entonces se genera una perturbación de contacto en (0.3, 0.6)
    Y al soltar el puntero la perturbación finaliza
```

```gherkin
# language: es
@render
Característica: Refracción del mundo a través de la membrana

  Escenario: RF-40 La refracción altera el mundo solo donde la membrana se deforma
    Dado el mundo de referencia renderizado con la membrana en reposo y el reposo orgánico desactivado
    Cuando se aplica una perturbación de contacto guionada en el centro de la pantalla y se avanzan 10 pasos
    Entonces la región central difiere de la imagen en reposo por encima del umbral de diferencia
    Y las cuatro esquinas no difieren por encima del umbral de diferencia
```

```gherkin
# language: es
@despliegue
Característica: Despliegue y privacidad

  Escenario: RF-50 Despliegue con un solo comando
    Dado Docker disponible en el equipo
    Cuando se ejecuta "docker compose up --build" desde la raíz del proyecto
    Entonces la aplicación responde con estado 200 en http://localhost:8080
    Y los archivos WASM se sirven con el tipo "application/wasm"
    Y el proceso del servidor no se ejecuta como root

  Escenario: RF-51 Ninguna imagen sale del dispositivo
    Dado la aplicación servida por el contenedor y una cámara falsa activa
    Cuando se usa durante 30 segundos
    Entonces todas las peticiones de red son GET al propio origen
    Y no se produce ninguna petición después de que la detección esté lista
```

Herramienta BDD (ADR-008):

- **Vitest.** RF-01 a RF-04 y RF-10 a RF-13 se ejecutan con @amiceli/vitest-cucumber sobre las capas de dominio y aplicación, con adaptadores falsos: reloj manual, fuente guionada y solver de CPU. Si vitest-cucumber resulta incompatible con la versión fijada de Vitest, el respaldo es quickpickle; regístralo como desvío.
- **Playwright.** RF-20, RF-21, RF-40, RF-50 y RF-51 dependen del navegador o del contenedor. Se implementan como pruebas Playwright con un `test.step` por cada Dado, Cuando y Entonces, y el identificador RF en el nombre de la prueba. Su .feature se conserva en `web/tests/e2e/features/` como especificación.
- **Umbrales de RF-40:**
  - región central: cuadrado centrado de lado igual al 10 % del ancho del lienzo; diferencia absoluta media por canal ≥ 4/255;
  - esquinas: cuatro cuadrados de lado igual al 5 % del ancho; diferencia ≤ 1/255.

  Si el render sin interfaz gráfica (SwiftShader) obliga a cambiarlos, informa del valor medido y de la causa; no los relajes en silencio.

## Restricciones de diseño

### Patrones

- Puertos y adaptadores (ADR-003).
- Strategy:
  - solver de membrana: en esta fase solo existe el de CPU, pero el puerto ya está definido;
  - estimador de proximidad: tamaño aparente o profundidad;
  - Mundo: punto de extensión del adaptador de render.
- Adapter: cada fuente sensorial traduce su API al contrato de observación.
- Observer ligero (callback o EventTarget; sin librerías reactivas) entre la fuente y la aplicación.
- Game loop de paso fijo con acumulador y un tope de pasos por frame, para evitar la espiral de la muerte tras pausas largas.
- Raíz de composición con inyección manual en `arranque`.
- Búferes preasignados en el bucle caliente: el solver no asigna memoria por paso.

### Principios

SRP y DIP estrictos. Los ADR vigentes son restricciones de obligado cumplimiento. Regla de dependencia de la sección 5.3 del plan:

1. `dominio/**` no importa nada fuera de su propio módulo; `dominio/membrana` y `dominio/interaccion` no se importan entre sí.
2. `aplicacion/**` solo importa `dominio/**`.
3. Un adaptador no importa otro adaptador.
4. Solo `arranque/**` importa `adaptadores/**`; nadie importa `arranque/**`.
5. three y @mediapipe/tasks-vision solo se importan desde `adaptadores/**`.
6. `dominio/**` y `aplicacion/**` no usan globales del navegador (window, document, navigator, performance, requestAnimationFrame, localStorage). El tiempo entra por el puerto de reloj.
7. No hay ciclos.

Las reglas 1 a 5 y 7 se implementan en dependency-cruiser; la regla 6, con `no-restricted-globals` de ESLint aplicado a esas carpetas.

### Contratos públicos

Las firmas exactas son tuyas; los campos y la semántica no.

- **Observación** (ADR-004):
  - identificador de la fuente;
  - marca de tiempo de captura (ms, reloj monotónico);
  - objetivo: mano, rostro o puntero;
  - identificador provisional del objetivo según el sensor (opcional);
  - posición en la imagen normalizada a [0, 1], con origen arriba a la izquierda y sin espejo;
  - tamaño aparente como fracción de la diagonal de la imagen (opcional);
  - profundidad en metros (opcional; obligatoria si falta el tamaño);
  - confianza en [0, 1].

  Una observación sin tamaño ni profundidad es inválida y se rechaza en el dominio. El espejo es configuración de la fuente.
- **Lote de observaciones:** la fuente emite un lote por fotograma procesado, que puede estar vacío, con la marca de captura. Un lote vacío significa "no se ve ningún objetivo" y es lo que permite finalizar las perturbaciones.
- **Perturbación:**
  - identificador;
  - objetivo;
  - posición en pantalla normalizada a [0, 1], ya con espejo;
  - proximidad en [0, 1];
  - zona: ninguna, influencia o contacto;
  - intensidad en [0, 1];
  - radio normalizado;
  - marca de tiempo.

  En esta fase el identificador es el provisional del sensor. Una perturbación existe mientras su objetivo aparece en el último lote con zona distinta de ninguna, y finaliza en cuanto deja de aparecer (el tiempo de gracia llega en FASE-02).
- **Excitación:** posición, amplitud y radio normalizados. Es la entrada del dominio de membrana; la aplicación traduce las perturbaciones en excitaciones.
- **Puertos de la aplicación:**
  - FuenteSensorial: iniciar, de forma asíncrona y con errores tipificados (permiso denegado, sin dispositivo, fallo al cargar el modelo); detener; suscribirse a lotes; consultar estado.
  - SolverMembrana: configurar resolución y parámetros; aplicar las excitaciones del paso; avanzar un paso fijo; exponer una vista de solo lectura del campo, el desplazamiento máximo y la energía.
  - Presentador: presentar el estado del frame; redimensionar.
  - Reloj: tiempo monotónico en ms.
  - Telemetría: registrar los tiempos de frame, de trabajo del tick y de inferencia; consultar el resumen (media y p95).
- **Gancho de prueba:** solo existe con `?modo=prueba`. En ese modo el bucle arranca en pausa y se expone en `window.__membrana`:
  - una función de estado que devuelve una copia con la fuente activa, el solver en uso, las perturbaciones activas, si la detección está lista y el aviso visible;
  - una función para avanzar N pasos de simulación y presentar.

  En modo normal el gancho no existe. Es el contrato entre las pruebas extremo a extremo y la aplicación.
- **Configuración por URL:**
  - `fuente=camara|puntero|guionada` (por defecto, cámara; si falla, pasa a puntero con aviso);
  - `guion=<nombre>` para la fuente guionada (guiones registrados en el código);
  - `modo=prueba`.

### Modelo físico de la membrana

Es una especificación del dominio, no pseudocódigo. Campo de alturas h sobre una rejilla:

∂²h/∂t² = c²∇²h − γ·∂h/∂t − k·h + f(x, t)

- c: velocidad de propagación (tensión).
- γ: amortiguamiento viscoso.
- k: término restaurador hacia el reposo.
- f: suma de excitaciones con perfil gaussiano de radio r y amplitud proporcional a la intensidad.

Requisitos del modelo:

- **Bordes:** fijos (h = 0), como una membrana tensada sobre el marco.
- **Integración:** esquema explícito de segundo orden; la discretización la eliges tú. Paso fijo configurable, por defecto 1/120 s.
- **Estabilidad:** la condición CFL 2D (c·Δt/Δx ≤ 1/√2) es un invariante del dominio. Los parámetros que la violarían se corrigen aumentando los subpasos o se rechazan con un error de dominio en español; elige una opción y justifícala.
- **Energía:** la energía discreta (cinética, elástica y restauradora) se expone para RF-03.
- **Valores por defecto:** resolución baja configurable (orientativa: 160×90) y parámetros que cumplan RF-01 y RF-03. La tolerancia de reposo y los demás umbrales se definen como constantes con nombre en el dominio.

### Estimación de proximidad

- **Por tamaño:** proximidad lineal entre las referencias de influencia y de contacto, recortada a [0, 1]. Zona ninguna por debajo de la referencia de influencia; contacto en la de contacto o por encima. La intensidad es una función monótona de la proximidad, con f(0) = 0, f(1) = 1 y valores estrictamente entre 0 y 1 en la zona de influencia.
- **Referencias por defecto de mano (orientativas):** influencia ≈ 0.10 y contacto ≈ 0.19 de la diagonal, que equivalen a unos 55 cm y 30 cm con una webcam de unos 70° de campo horizontal.
- **Por profundidad:** el mismo esquema con distancias invertidas. Si una observación trae tamaño y profundidad, prevalece la profundidad.
- **Puntero:** pulsado se modela como profundidad 0 m (contacto, sin espejo); al soltar, emite un lote vacío. Así el puntero no necesita ningún caso especial en el dominio.
- **Tamaño aparente de la mano** (lo calcula el adaptador de cámara, no el dominio): medida robusta a la rotación, el máximo de dos segmentos de palma aproximadamente ortogonales (muñeca a MCP medio; MCP índice a MCP meñique). Se mide en espacio de píxeles y se divide por la diagonal de la imagen. Las coordenadas normalizadas de MediaPipe están escaladas por separado en x e y; no midas distancias directamente sobre ellas.

### Render (adaptador)

- Three.js con WebGLRenderer (WebGL2).
- El mundo de referencia es un patrón procedural determinista de alto contraste (cuadrícula, gradiente y formas). Se dibuja en un destino de render fuera de pantalla.
- La textura de alturas se sube desde la CPU cada frame. Usa un formato filtrable linealmente sin extensiones (p. ej., coma flotante de 16 bits) o filtra en el shader: la coma flotante de 32 bits necesita una extensión para el filtrado lineal.
- La pasada de composición calcula la normal a partir del gradiente del campo y desplaza el muestreo del mundo en proporción a la fuerza de refracción, que es un parámetro.
- Lienzo a pantalla completa, con redimensionado y densidad de píxeles limitada (orientativa: máximo 2).

### Sensórica de cámara (adaptador)

- getUserMedia más HandLandmarker de @mediapipe/tasks-vision en el hilo principal, con delegado GPU y respaldo en CPU, y hasta 2 manos.
- Procesa siempre el fotograma más reciente: requestVideoFrameCallback cuando esté disponible; nunca acumula colas.
- El WASM se copia desde node_modules a `web/public/wasm/` en el build.
- El modelo `hand_landmarker.task` se descarga una vez desde el almacenamiento oficial de modelos de MediaPipe, con ruta versionada (no `latest`). Se guarda en `web/public/modelos/` y su SHA-256 se registra en `web/public/modelos/SHA256SUMS` y en el retorno.
- En tiempo de ejecución no hay ninguna petición a orígenes ajenos.

### Instrumentación (Amdahl)

- La telemetría registra, por frame, el tiempo de trabajo del tick (simulación y envío del render) y, cuando hay inferencia, su duración.
- Definición de P = Σ inferencia / Σ (inferencia + trabajo del tick) durante la sesión.
- El panel de diagnóstico, que se activa con la tecla D, muestra: fps, tiempo de frame p95, inferencia media y p95, P, número de perturbaciones y fuente activa.
- Marca de rendimiento `primer-frame-interactivo`: cuando la fuente está lista y se presenta el primer frame.

### Límites de acoplamiento

Lo que está prohibido: cualquier import que viole la regla de dependencia; la lógica de dominio dentro de los adaptadores; las APIs del navegador en el dominio o la aplicación; las dependencias no autorizadas en la sección Entorno.

### Umbrales de métricas estáticas (.flow/tools/metricas_config.yml)

- Complejidad ciclomática ≤ 10 por función.
- ≤ 20 líneas por función (sin contar líneas en blanco ni comentarios).
- Cobertura de líneas ≥ 80 % en `src/dominio` más `src/aplicacion`.
- D < 0.3 en todos los módulos.
- I < 0.5 en los módulos del núcleo.
- A > 0.5 en los módulos estables.

Clasificación de módulos:

| Módulo | nucleo | estable |
|---|---|---|
| dominio/membrana | true | true |
| dominio/interaccion | true | true |
| aplicacion | true | true |
| adaptadores/sensorica, adaptadores/render, adaptadores/ui | false | false |
| arranque | false | false |

Riesgo conocido: un módulo de dominio con I ≈ 0 necesita A > 0.7 para tener D < 0.3. Si no se alcanza por la naturaleza algorítmica del módulo, no lo maquilles: repórtalo con su análisis.

## Tareas detalladas (con TDD)

Cada tarea sigue el ciclo rojo, verde, refactorización. En las tareas de herramientas, el "rojo" consiste en introducir una violación temporal que demuestre que la regla falla, retirarla y dejar constancia en el retorno.

1. **Andamiaje y cadena de calidad.**
   - Crea `web/` con Vite y TypeScript estricto (incluido `noUncheckedIndexedAccess`).
   - Configura Vitest con cobertura v8 (`json-summary`), vitest-cucumber, ESLint 9 con typescript-eslint (`complexity` 10, `max-lines-per-function` 20 sin blancos ni comentarios, `no-restricted-globals` en dominio y aplicación) y dependency-cruiser con las reglas 1 a 5 y 7.
   - Demuestra que cada regla falla ante una violación temporal.
2. **Parámetros de membrana y CFL.**
   - Pruebas: aceptación de parámetros válidos; corrección o rechazo de los que violan CFL; límites de rango con mensajes de error de dominio en español.
3. **Solver de CPU de referencia.**
   - Pruebas: reposo estable sin NaN ni infinitos; excitación localizada; bordes fijos; energía decreciente sin excitación; retorno a la tolerancia de reposo; monotonía respecto a la intensidad; sin asignaciones de memoria por paso (búferes preasignados).
   - Después, los pasos de RF-01 a RF-04.
4. **Interacción.**
   - Pruebas: validación de la observación; estimador por tamaño; estimador por profundidad; prioridad de la profundidad; zonas en los límites exactos; monotonía de la intensidad; espejo; radio.
   - Después, los pasos de RF-10 a RF-13.
5. **Aplicación.**
   - Puertos y casos de uso con adaptadores falsos (reloj manual, fuente guionada, solver de CPU).
   - Pruebas:
     - lote a perturbaciones activas;
     - finalización al desaparecer el objetivo;
     - traducción de perturbación a excitación;
     - acumulador de paso fijo, incluido el tope de pasos tras una pausa larga;
     - tick con telemetría.
6. **Fuentes sensoriales.**
   - Fuente guionada.
   - Fuente de puntero: la traducción de evento a observación es una función pura probada; el enganche al DOM es mínimo.
   - Fuente de cámara: el cálculo de tamaño aparente en espacio de píxeles es una función pura probada; errores tipificados; semántica de último fotograma.
7. **Render.**
   - Mundo de referencia, textura de alturas, compositor de refracción y punto de extensión Mundo.
   - Las funciones auxiliares puras (conversión de coordenadas, tamaños) llevan pruebas; los shaders se validan con RF-40.
8. **UI y arranque.**
   - Aviso de cámara en español con paso a puntero; pantalla completa con la tecla F; panel de diagnóstico con la tecla D.
   - Raíz de composición, configuración por URL, gancho de prueba y marca `primer-frame-interactivo`.
9. **Pruebas extremo a extremo con Playwright (Chromium).**
   - RF-20: sin dispositivo o con el permiso denegado.
   - RF-21: pulsación en (0.3, 0.6) y verificación mediante el gancho.
   - RF-40: fuente guionada, `modo=prueba` y comparación por regiones.
   - Prueba de humo con cámara falsa (`--use-fake-ui-for-media-stream`, `--use-fake-device-for-media-stream`): la detección queda lista sin errores.
10. **Despliegue.**
    - `despliegue/Dockerfile` de varias etapas (node:24-alpine para construir; nginxinc/nginx-unprivileged:alpine para servir en el puerto 8080).
    - `despliegue/nginx.conf`: MIME `application/wasm`; recursos con hash cacheados como inmutables; `index.html` sin caché.
    - `compose.yaml` en la raíz y `.dockerignore`, que excluye node_modules, .flow y los resultados de pruebas.
    - RF-50 y RF-51 contra el contenedor, mediante el script `verificar:contenedor`.
11. **Medición en el equipo de referencia** con webcam real (ver Métricas a reportar).
12. **Métricas, gate y auto-revisión.**
    - Script `web/herramientas/metricas/` que genere `.flow/metrics/FASE-01.json`.
    - Gate y auto-revisión según tu rol.

## Tests requeridos

- **Unitarios:** todos los de las tareas 2 a 8. Incluye casos límite (valores exactamente en las referencias, campo vacío, lote vacío, parámetros en el borde de CFL, pausa larga del reloj) y casos de error (observación sin tamaño ni profundidad, parámetros fuera de rango, fallos de la cámara).
- **Aceptación BDD:** RF-01 a RF-04 y RF-10 a RF-13 con vitest-cucumber.
- **Extremo a extremo:** RF-20, RF-21 y RF-40, más la prueba de humo de cámara falsa, con Playwright.
- **Contra el contenedor:** RF-50 y RF-51.
- **Cobertura:** ≥ 80 % de líneas en `src/dominio` y `src/aplicacion`. Los adaptadores de render y sensórica no cuentan para el gate.
- **Scripts npm obligatorios** (para que la evidencia sea reproducible): `dev`, `build`, `test` (unitarios y aceptación), `test:cobertura`, `test:e2e`, `lint`, `deps`, `metricas` y `verificar:contenedor`.

## Métricas a reportar

### Gate estático

- El script `npm run metricas` genera `.flow/metrics/FASE-01.json` con el esquema canónico de la cabecera de `.flow/tools/verificar_fase.py`.
- Las salidas crudas se guardan en `.flow/metrics/fuentes/FASE-01/` y se referencian en `fuentes`.
- Complejidad y líneas: reporta los valores máximos observados, no solo las violaciones. Una forma es ejecutar ESLint en modo medición, con los umbrales al mínimo y salida JSON, y extraer los valores de los mensajes.
- Cobertura: `lines.pct / 100` de la suma de `src/dominio` y `src/aplicacion`.
- I por módulo, contando a nivel de módulo:
  - Ce = número de módulos distintos de los que depende, contando cada paquete externo como un módulo e incluyendo los imports de solo tipos;
  - Ca = número de módulos distintos que dependen de él;
  - I = Ce / (Ca + Ce), con I = 0 si ambos son 0.
- A por módulo (ADR-008): abstractos = interfaces, alias de tipo y clases abstractas; concretos = clases y funciones exportadas de nivel superior.
- D = |A + I − 1|.

Ejecuta `python .flow/tools/verificar_fase.py FASE-01` desde la raíz y pega la salida completa en el retorno. Reporta además la complejidad máxima y media, las líneas máximas, I, A y D por módulo, y señala explícitamente cualquier valor fuera de umbral.

### Medición en el equipo de referencia

Sesión de al menos 60 s con webcam real y una mano en movimiento. Reporta:

- especificaciones del equipo: CPU, GPU, RAM, versión del navegador, modelo de webcam, y resolución y fps de captura;
- fps medio y tiempo de frame p95 con detección activa (RNF-01; en esta fase solo se informa);
- tiempo de inferencia medio y p95, y fracción P (Amdahl);
- JS inicial comprimido con gzip y transferencia total de la primera carga, modelos y WASM incluidos (RNF-07; solo se informa);
- tiempo hasta `primer-frame-interactivo` con caché caliente y en primera carga (RNF-06; solo se informa);
- tamaño de la imagen Docker y tiempo de build desde cero (RNF-10; exigible).

## Entorno

- Lenguaje: TypeScript (estricto), última estable publicada hace al menos dos semanas, versión exacta.
- Runtime: Node.js 24 LTS.
- Framework y construcción: Vite, versión exacta. Sin framework de interfaz: el DOM de la UI es mínimo.
- Dependencias de ejecución autorizadas: three y @mediapipe/tasks-vision.
- Dependencias de desarrollo autorizadas: vitest, @vitest/coverage-v8, @amiceli/vitest-cucumber (o quickpickle como respaldo, registrado como desvío), @playwright/test (solo Chromium), eslint 9, typescript-eslint, dependency-cruiser y @types/three si hace falta.
- Gestor: npm con `web/package.json` y `package-lock.json`. Versiones exactas, sin ^ ni ~. Registra en el retorno la tabla de versiones instaladas.
- Contenedores: Docker Desktop con WSL2 y Compose v2. Imágenes node:24-alpine y nginxinc/nginx-unprivileged:alpine con etiqueta fija.
- Python (solo para ejecutar el gate del kit).

## Estructura de carpetas esperada

```
cámaraSintec/
├─ web/
│  ├─ src/dominio/membrana/
│  ├─ src/dominio/interaccion/
│  ├─ src/aplicacion/                 (casos de uso y puertos)
│  ├─ src/adaptadores/sensorica/      (cámara MediaPipe, puntero, guionada)
│  ├─ src/adaptadores/render/         (presentador Three, mundo de referencia, compositor)
│  ├─ src/adaptadores/ui/             (aviso, pantalla completa, panel de diagnóstico)
│  ├─ src/arranque/                   (raíz de composición, configuración, gancho de prueba)
│  ├─ public/wasm/  public/modelos/   (con SHA256SUMS)
│  ├─ tests/unit/
│  ├─ tests/aceptacion/               (.feature y pasos de vitest-cucumber)
│  ├─ tests/e2e/                      (Playwright y features/ de especificación)
│  ├─ herramientas/metricas/
│  ├─ package.json, package-lock.json, tsconfig.json, vite.config.ts,
│  │  vitest.config.ts, playwright.config.ts, eslint.config.js, .dependency-cruiser.cjs
├─ despliegue/Dockerfile
├─ despliegue/nginx.conf
├─ compose.yaml
├─ .dockerignore
└─ .flow/metrics/FASE-01.json, .flow/metrics/fuentes/FASE-01/
```

## Productos de salida

- Todo el código de `web/src/` según la estructura anterior.
- Pruebas en `web/tests/unit/`, `web/tests/aceptacion/` (archivos .feature de membrana, interacción y fuentes en lo que corresponda) y `web/tests/e2e/`.
- Configuraciones de calidad: ESLint, dependency-cruiser, Vitest y Playwright.
- `web/herramientas/metricas/` con el script de métricas.
- `web/public/modelos/hand_landmarker.task` y `SHA256SUMS`; WASM copiado por el build.
- `despliegue/Dockerfile`, `despliegue/nginx.conf`, `compose.yaml` y `.dockerignore`.
- `.flow/metrics/FASE-01.json` y `.flow/metrics/fuentes/FASE-01/`.
- `.flow/state/retorno_ejecutor.md` y la entrada en `.flow/state/handoff_log.md`.

## DoD de la fase

- [ ] Escenarios RF-01, RF-02, RF-03, RF-04, RF-10, RF-11, RF-12, RF-13, RF-20, RF-21, RF-40, RF-50 y RF-51 implementados y en verde.
- [ ] Pruebas unitarias en verde; cobertura de líneas ≥ 80 % en dominio y aplicación.
- [ ] `npm run deps` sin violaciones de la regla de dependencia; `npm run lint` sin errores.
- [ ] Cada regla de dependencia y de ESLint se ha demostrado capaz de fallar ante una violación temporal, con evidencia en el retorno.
- [ ] `.flow/metrics/FASE-01.json` generado según el esquema y gate APTO, o violación reportada con análisis de causa.
- [ ] `docker compose up --build` sirve la aplicación en http://localhost:8080; RF-50 y RF-51 pasan contra el contenedor; imagen ≤ 150 MB; build desde cero ≤ 5 min.
- [ ] En tiempo de ejecución, ninguna petición a orígenes ajenos: modelo y WASM alojados en el propio servidor, con el SHA-256 del modelo registrado.
- [ ] Prueba manual con webcam real en el equipo de referencia: al acercar la mano, la membrana se deforma en la posición espejada correspondiente. Evidencia: captura o vídeo breve más las lecturas del panel de diagnóstico.
- [ ] Informe de medición completo según la sección "Medición en el equipo de referencia", incluida la fracción P.
- [ ] Estructura de carpetas, contratos y gancho de prueba conformes a este prompt.
- [ ] Auto-revisión final realizada (sección 6 del rol ejecutor).

## Notas adicionales

- **Idioma:** identificadores del dominio en español sin tildes (Membrana, Observacion, Perturbacion, Excitacion, Proximidad, Zona). Textos de la interfaz y mensajes de error, en español.
- **Errores:** errores de dominio tipificados con mensaje en español. Los fallos de cámara se convierten en un aviso visible y en el paso a la fuente de puntero, nunca en una excepción sin capturar. En consola, solo `console.error` para errores no recuperables; nada de restos de depuración.
- **Alcance:** no implementes nada de lo listado como fuera de alcance en el Objetivo general. Si alguna pieza de FASE-02 o posterior parece necesaria, es un bloqueo o una nota para el planificador, no una ampliación silenciosa.
- **Ruta con tilde:** la ruta del proyecto contiene "á" (riesgo R8). Si alguna herramienta falla por ello, detente y repórtalo como bloqueo; renombrar la carpeta es decisión del usuario.
- **Git:** no hagas operaciones de Git. Los commits los hace el usuario. Se le ha recomendado crear un repositorio propio en cámaraSintec (riesgo R9).
- **Descargas:** la del modelo de MediaPipe es la única autorizada. Debe venir de la fuente oficial, con ruta versionada y checksum registrado.

---
Al terminar, escribe tu informe en .flow/state/retorno_ejecutor.md usando la plantilla .flow/prompts/template_retorno.md y actualiza .flow/state/handoff_log.md.
