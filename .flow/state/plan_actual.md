# Design Doc: Membrana Interactiva (cámaraSintec)

- Versión: 1
- Fecha: 2026-10-21
- Autor: Planificador
- Estado: arquitectura cerrada por delegación expresa del usuario ("analiza cada situación y toma las decisiones óptimas"). Los escenarios de FASE-01 están pendientes de validación por el usuario; el prompt de ejecución no se emite hasta entonces.
- Decisiones vigentes: ADR-001 a ADR-009 (.flow/state/decisiones.md).

---

## 1. Contexto y problema

Se quiere un sistema interactivo en tiempo real que simule una membrana física situada entre el observador y un mundo virtual en pantalla. La membrana es una película translúcida con comportamiento de tensión superficial (agua o celulosa elástica) que cubre toda la pantalla. El usuario no toca la pantalla: la cámara detecta cuánto se acercan sus manos o su rostro, y esa proximidad deforma la membrana en el punto correspondiente. La deformación refracta y estira la imagen del mundo que hay detrás y genera ondas que se expanden y se amortiguan hasta volver a la calma.

Situación actual: no existe código. El sistema será la base de otros proyectos: debe admitir otros mundos visuales, otros sensores (RGB hoy; RGBD u otros mañana) y otros despliegues (web con la cámara del cliente, PC local, instalación con cámaras externas, nube con muchos clientes). En esta primera versión se prueba la funcionalidad completa en el equipo de desarrollo; la instalación en otros equipos y el despliegue en la nube vienen después.

Restricción física de partida: con una cámara RGB monocular no hay medida métrica fiable de la distancia. La proximidad se estima por referencias de tamaño aparente, con valores por defecto razonables y ajuste posterior mediante calibración y parámetros (ADR-004).

## 2. Objetivos y no-objetivos

### Objetivos

- O1. Experiencia completa: membrana en reposo con tensión superficial, deformación local por proximidad de manos y rostro, refracción, ondas expansivas y retorno amortiguado a la calma, con webcam RGB en el navegador del equipo de referencia y cumpliendo los requisitos no funcionales.
- O2. Base reutilizable: sensórica, interacción, física y render desacoplados por contratos (ADR-003, ADR-004), de modo que sensores, solvers y mundos se sustituyan sin tocar el núcleo.
- O3. Preparado para escalar: procesamiento en el cliente (ADR-001) y despliegue contenerizado sin estado (ADR-009), con un coste de servidor por cliente prácticamente nulo.
- O4. Ajustable: calibración de proximidad y parámetros físicos y visuales modificables en vivo, persistentes y exportables como perfil.
- O5. Aprovechamiento del equipo: GPU para inferencia y render, sensórica desacoplada del render y calidad adaptativa según las capacidades del equipo.

### No-objetivos (fuera de alcance de este plan)

- Paralaje por posición de la cabeza (proyección off-axis o efecto "ventana"). El mundo se ve desde una cámara virtual fija.
- Servicio de sensórica remota (cámaras RTSP o RGBD conectadas a otro equipo). Queda previsto por contrato (ADR-004) y como servicio futuro del compose (ADR-009), pero no se construye.
- Adaptador real para cámaras RGBD. La estrategia de proximidad por profundidad sí se implementa y se prueba con una fuente simulada.
- Procesamiento, almacenamiento o transmisión de imagen en un servidor; analítica; cuentas de usuario; gestión de múltiples clientes (multi-tenant).
- Despliegue productivo en la nube: TLS, dominio, orquestación y CDN. Se entrega la imagen Docker lista, no la infraestructura.
- Audio.
- Dispositivos móviles y entrada táctil como objetivo de aceptación (mejor esfuerzo).
- Empaquetado nativo (Electron u otro).
- Navegadores no basados en Chromium como objetivo de aceptación.
- Multipantalla, proyección sobre superficies o varias cámaras simultáneas.

## 3. Requisitos funcionales

Los escenarios se escriben en Gherkin en español (`# language: es`). La etiqueta indica la fase que los implementa. Los valores numéricos de los escenarios (referencias, tiempos, tolerancias) son de prueba: los valores por defecto de producción los fija el ejecutor y se ajustan con calibración.

### 3.1 Comportamiento físico de la membrana

```gherkin
# language: es
@membrana
Característica: Comportamiento físico de la membrana

  Antecedentes:
    Dado una membrana con los parámetros físicos por defecto

  @FASE-01
  Escenario: RF-01 La membrana en reposo permanece estable
    Dado que no hay perturbaciones activas
    Cuando transcurren 10 segundos de simulación
    Entonces el desplazamiento máximo es inferior a la tolerancia de reposo
    Y ningún valor del campo de alturas es infinito ni indefinido

  @FASE-01
  Escenario: RF-02 Una perturbación deforma la membrana en el punto de interacción
    Dado que la membrana está en reposo
    Cuando se aplica una perturbación de contacto en la posición (0.25, 0.75) durante 100 ms
    Entonces el punto de máximo desplazamiento está a menos de un radio de perturbación de (0.25, 0.75)

  @FASE-01
  Escenario: RF-03 La membrana recupera la calma al cesar la perturbación
    Dado que la membrana ha recibido un contacto sostenido de 1 segundo
    Cuando cesa toda perturbación
    Entonces la energía de la membrana al final de cada ventana de 250 ms es menor que al inicio de esa ventana
    Y en menos de 3 segundos el desplazamiento máximo vuelve a la tolerancia de reposo

  @FASE-01
  Escenario: RF-04 A mayor intensidad, mayor deformación
    Cuando se aplican por separado dos perturbaciones idénticas salvo en la intensidad, 0.3 y 0.9
    Entonces el desplazamiento máximo producido por la de 0.9 es mayor que el producido por la de 0.3

  @FASE-03
  Escenario: RF-05 La perturbación genera ondas que se propagan
    Dado que la membrana está en reposo
    Cuando se aplica una perturbación de contacto breve en el centro
    Entonces se forma un frente de onda que se aleja del centro
    Y su radio crece a la velocidad de propagación configurada, con una tolerancia del 15 por ciento

  @FASE-03
  Escenario: RF-06 Parámetros inestables no hacen divergir la simulación
    Cuando se configura una tensión que violaría la condición de estabilidad con el paso actual
    Entonces el solver aumenta los subpasos o limita el valor hasta cumplir la condición
    Y la simulación permanece acotada durante 60 segundos con perturbaciones continuas

  @FASE-03
  Escenario: RF-07 Reposo orgánico perceptible pero sutil
    Dado que el reposo orgánico está activo con una semilla fija
    Cuando transcurren 10 segundos sin perturbaciones
    Entonces el desplazamiento máximo es mayor que cero y menor que la amplitud de reposo configurada
    Y dos ejecuciones con la misma semilla producen el mismo campo de alturas

  @FASE-03
  Escenario: RF-08 El solver de GPU es equivalente al de referencia
    Dado el mismo estado inicial y la misma secuencia de perturbaciones
    Cuando el solver de GPU y el de CPU avanzan 120 pasos
    Entonces la diferencia máxima absoluta entre ambos campos es inferior al 1 por ciento de la amplitud máxima

  @FASE-03
  Escenario: RF-09 Sin texturas de coma flotante se usa el solver de referencia
    Dado un entorno gráfico sin texturas de coma flotante renderizables
    Cuando arranca la aplicación
    Entonces la membrana funciona con el solver de CPU a resolución reducida
    Y el panel de diagnóstico indica el solver en uso
```

### 3.2 Proximidad e interacción

```gherkin
# language: es
@interaccion
Característica: Proximidad e interacción

  @FASE-01
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

  @FASE-01
  Escenario: RF-11 La intensidad crece con la proximidad
    Dado las referencias de tamaño de mano: influencia 0.10 y contacto 0.20
    Cuando se observan dos manos con tamaños aparentes 0.12 y 0.18
    Entonces la intensidad de la mano de 0.18 es mayor que la de la mano de 0.12

  @FASE-01
  Escenario: RF-12 La cámara se comporta como un espejo
    Dado una fuente de cámara con el modo espejo activo
    Cuando se observa una mano en zona de contacto en la posición de imagen (0.2, 0.4)
    Entonces la perturbación se sitúa en la posición de pantalla (0.8, 0.4)

  @FASE-01
  Escenario: RF-13 Una fuente con profundidad usa la estimación por profundidad
    Dado las referencias de profundidad de mano: influencia 0.60 m y contacto 0.30 m
    Cuando se observa una mano a 0.25 m de profundidad sin tamaño aparente
    Entonces la zona de interacción es "contacto"
    Y si una observación aporta a la vez profundidad y tamaño aparente, prevalece la profundidad

  @FASE-02
  Escenario: RF-14 La histéresis evita el parpadeo en el umbral de contacto
    Dado una mano en zona de contacto
    Cuando su proximidad oscila alrededor del umbral de contacto con una amplitud menor que la histéresis configurada
    Entonces la zona permanece en "contacto" en todas las observaciones

  @FASE-02
  Escenario: RF-15 Varias manos generan perturbaciones independientes con identidad estable
    Dado dos manos observadas simultáneamente en zona de contacto
    Cuando ambas se desplazan durante 30 observaciones consecutivas sin cruzarse
    Entonces existen dos perturbaciones activas
    Y cada una conserva su identificador durante toda la secuencia

  @FASE-02
  Escenario: RF-16 La retirada del usuario finaliza la perturbación tras un tiempo de gracia
    Dado una mano en zona de contacto
    Cuando la mano deja de observarse
    Entonces la perturbación se mantiene durante el tiempo de gracia configurado
    Y después se da por finalizada y deja de excitar la membrana

  @FASE-02
  Escenario: RF-17 El acercamiento del rostro perturba con un radio mayor
    Dado un rostro y una mano observados con la misma proximidad
    Cuando se generan sus perturbaciones
    Entonces el radio de la perturbación del rostro es mayor que el de la mano, según la relación configurada

  @FASE-02
  Escenario: RF-18 Las observaciones de baja confianza se ignoran
    Dado un umbral mínimo de confianza configurado
    Cuando llega una observación con confianza inferior al umbral
    Entonces no genera ni actualiza ninguna perturbación

  @FASE-02
  Escenario: RF-19 El suavizado reduce el temblor sin retrasar el movimiento real
    Dado una mano inmóvil observada con ruido de posición de amplitud 0.01
    Cuando se procesan 60 observaciones
    Entonces la desviación típica de la posición de la perturbación es al menos un 50 por ciento menor que la del ruido de entrada
    Y ante un salto real de posición la perturbación alcanza el 90 por ciento del salto en no más de 3 observaciones
```

### 3.3 Fuentes sensoriales intercambiables

```gherkin
# language: es
@sensorica
Característica: Fuentes sensoriales intercambiables

  @FASE-01
  Escenario: RF-20 Sin cámara la aplicación sigue siendo utilizable con el puntero
    Dado que el acceso a la cámara es denegado o no existe cámara
    Cuando arranca la aplicación
    Entonces se muestra un aviso en español que indica que se usará el puntero
    Y no aparecen errores no controlados en la consola

  @FASE-01
  Escenario: RF-21 La fuente de puntero produce contactos equivalentes
    Dado la fuente de puntero activa
    Cuando se pulsa el puntero en la posición de pantalla (0.3, 0.6)
    Entonces se genera una perturbación de contacto en (0.3, 0.6)
    Y al soltar el puntero la perturbación finaliza

  @FASE-02
  Escenario: RF-22 La sensórica procesa siempre el fotograma más reciente
    Dado un detector más lento que la cámara
    Cuando llegan varios fotogramas mientras se procesa uno
    Entonces el siguiente fotograma procesado es el más reciente
    Y nunca hay más de un fotograma pendiente
```

### 3.4 Calibración y ajuste de parámetros

```gherkin
# language: es
@calibracion
Característica: Calibración y ajuste de parámetros

  @FASE-04
  Escenario: RF-30 Calibración de dos puntos para la mano
    Dado el asistente de calibración iniciado para el objetivo "mano"
    Cuando el usuario mantiene la mano en la posición lejana y después en la cercana durante el tiempo indicado
    Entonces las referencias de influencia y de contacto se calculan a partir de las medianas de los tamaños observados
    Y las nuevas referencias se aplican de inmediato y persisten tras recargar la página

  @FASE-04
  Escenario: RF-31 Un parámetro cambiado en vivo se aplica sin reiniciar
    Dado la simulación en marcha
    Cuando se modifica el amortiguamiento en el panel de parámetros
    Entonces el siguiente paso de simulación usa el nuevo valor
    Y el valor persiste tras recargar la página

  @FASE-04
  Escenario: RF-32 Exportar e importar un perfil de configuración
    Dado un perfil con calibración y parámetros personalizados
    Cuando se exporta a JSON y se importa en una sesión limpia
    Entonces la configuración resultante es idéntica a la exportada

  @FASE-04
  Escenario: RF-33 Un perfil inválido se rechaza sin alterar la configuración
    Dado una configuración activa
    Cuando se importa un perfil con una versión desconocida o un valor fuera de rango
    Entonces se muestra un mensaje en español que indica el campo inválido
    Y la configuración activa no cambia

  @FASE-04
  Escenario: RF-34 Restablecer valores por defecto
    Cuando se elige "Restablecer valores por defecto"
    Entonces todos los parámetros y referencias vuelven a sus valores por defecto y se persisten
```

### 3.5 Render y refracción

```gherkin
# language: es
@render
Característica: Refracción del mundo a través de la membrana

  @FASE-01
  Escenario: RF-40 La refracción altera el mundo solo donde la membrana se deforma
    Dado el mundo de referencia renderizado con la membrana en reposo y el reposo orgánico desactivado
    Cuando se aplica una perturbación de contacto guionada en el centro de la pantalla y se avanzan 10 pasos
    Entonces la región central difiere de la imagen en reposo por encima del umbral de diferencia
    Y las cuatro esquinas no difieren por encima del umbral de diferencia
```

### 3.6 Despliegue y privacidad

```gherkin
# language: es
@despliegue
Característica: Despliegue y privacidad

  @FASE-01
  Escenario: RF-50 Despliegue con un solo comando
    Dado Docker disponible en el equipo
    Cuando se ejecuta "docker compose up --build" desde la raíz del proyecto
    Entonces la aplicación responde con estado 200 en http://localhost:8080
    Y los archivos WASM se sirven con el tipo "application/wasm"
    Y el proceso del servidor no se ejecuta como root

  @FASE-01
  Escenario: RF-51 Ninguna imagen sale del dispositivo
    Dado la aplicación servida por el contenedor y una cámara falsa activa
    Cuando se usa durante 30 segundos
    Entonces todas las peticiones de red son GET al propio origen
    Y no se produce ninguna petición después de que la detección esté lista
```

### 3.7 Calidad adaptativa

```gherkin
# language: es
@rendimiento
Característica: Calidad adaptativa

  @FASE-05
  Escenario: RF-60 El perfil de calidad inicial depende de las capacidades del equipo
    Dado un informe de capacidades del equipo
    Cuando se calcula el perfil de calidad inicial
    Entonces se elige el perfil más alto cuyos requisitos cumple el equipo

  @FASE-05
  Escenario: RF-61 El regulador sostiene la fluidez y recupera la calidad con histéresis
    Dado el perfil de calidad alto y un tiempo de frame p95 superior a 16.7 ms durante 2 segundos
    Cuando actúa el regulador de rendimiento
    Entonces baja un nivel de calidad
    Y no vuelve a subir hasta que el tiempo de frame p95 se mantiene por debajo de 12 ms durante 5 segundos
```

### 3.8 Requisitos verificables sin Gherkin

- RF-70 (FASE-01 parcial, FASE-02 completo). Panel de diagnóstico que se activa y desactiva con una tecla. Muestra fps, tiempo de frame p95, latencia de pipeline p95, número de perturbaciones activas, fuente y solver en uso, y una vista de la cámara con los puntos detectados.
- RF-71 (FASE-01). La fuente sensorial se elige por configuración (parámetro de URL y, desde FASE-04, perfil): cámara, puntero o guionada.
- RF-72 (todas). Todos los textos de la interfaz y los mensajes de error, en español.
- RF-73 (FASE-01). Modo de pantalla completa con una tecla, apto para kiosko.
- RF-74 (FASE-02). Exportación desde el panel de diagnóstico de las mediciones de rendimiento de la sesión (tiempos de frame, latencias, frecuencia de detección) en JSON, que sirve de evidencia para los requisitos no funcionales.

## 4. Requisitos no funcionales

Equipo de referencia: el PC de desarrollo actual (Windows 11 Pro). Sus especificaciones (CPU, GPU, RAM, versión del navegador, modelo de webcam, resolución y fps de captura) se registran en el retorno de FASE-01 y forman la línea base. Todas las mediciones se hacen con la instrumentación interna (RF-74) en sesiones de al menos 60 s, salvo que se indique otra cosa.

| ID | Requisito | Umbral | Exigible desde |
|---|---|---|---|
| RNF-01 | Fluidez del render con detección activa, a 1920×1080 | tiempo de frame p95 ≤ 16.7 ms (≥ 60 fps) | FASE-02 (FASE-01 solo informa) |
| RNF-02 | Frecuencia efectiva de detección con webcam de 30 fps | ≥ 25 Hz | FASE-02 |
| RNF-03 | Latencia de pipeline instrumentada: de la marca de captura del fotograma al primer frame presentado que incorpora la perturbación | p95 ≤ 50 ms | FASE-02 |
| RNF-03b | Latencia de movimiento a imagen (objetivo de experiencia) | ≤ 100 ms; verificación manual opcional con cámara de alta velocidad, no forma parte del gate | Informativo |
| RNF-04 | Resolución de la simulación en el perfil alto sin violar RNF-01 | ≥ 512 celdas en el eje mayor | FASE-03 |
| RNF-05 | Privacidad | 0 peticiones a orígenes ajenos; 0 bytes de imagen transmitidos | FASE-01 |
| RNF-06 | Arranque hasta el primer frame interactivo | ≤ 3 s con caché caliente; ≤ 8 s en primera carga desde servidor local | FASE-05 (FASE-01 solo informa) |
| RNF-07 | Peso de la aplicación | JS inicial ≤ 500 KB comprimido con gzip; transferencia total de la primera carga, modelos y WASM incluidos, ≤ 25 MB | FASE-05 (FASE-01 solo informa) |
| RNF-08 | Estabilidad en sesión continua de 60 min | crecimiento del heap JS ≤ 10 % tras el calentamiento; caída del fps medio ≤ 5 % | FASE-05 |
| RNF-09 | Presión de memoria en el bucle caliente | cero asignaciones por frame en simulación y render; ninguna pausa de recolección de basura > 5 ms en un perfil de 60 s | FASE-03 |
| RNF-10 | Despliegue | build de la imagen desde cero ≤ 5 min en el equipo de referencia; imagen final ≤ 150 MB; servidor sin privilegios de root | FASE-01 |
| RNF-11 | Escalabilidad | servidor sin estado por cliente ni endpoints dinámicos; coste por cliente = transferencia de estáticos cacheables | FASE-01 (por diseño) |
| RNF-12 | Compatibilidad | Chrome y Edge estables actuales en Windows 11; resto, mejor esfuerzo | Todas |

## 5. Arquitectura propuesta (C4, niveles 1 a 3)

### 5.1 Nivel 1: contexto

- Sistema: Membrana Interactiva.
- Personas:
  - Participante: se sitúa frente a la pantalla y acerca las manos o el rostro para perturbar la membrana.
  - Operador: calibra, ajusta parámetros y despliega. Durante el desarrollo es el propio equipo.
- Sistemas externos:
  - Dispositivo de captura: webcam del cliente, accesible desde el navegador. En el futuro, sensores RGBD.
  - Navegador web con GPU: entorno de ejecución que aporta WebGL2, WASM y getUserMedia.
  - Infraestructura de distribución: servidor estático local o, en el futuro, CDN.
  - Servicio de sensórica remota (futuro, fuera de alcance): cámaras RTSP o RGBD de otro equipo.
- Relaciones:
  - El participante es captado por el dispositivo de captura y ve el resultado en la pantalla.
  - El operador configura el sistema a través de su interfaz.
  - El sistema se descarga de la infraestructura de distribución y después funciona sin ella.

### 5.2 Nivel 2: contenedores

| Contenedor | Tecnología | Responsabilidad | Comunicación |
|---|---|---|---|
| C-A Aplicación web (membrana-web) | SPA TypeScript en el navegador | Captura, inferencia, interacción, simulación, render e interfaz. Hilo principal más, desde FASE-02 si Amdahl lo justifica, un Worker de sensórica | Recibe los estáticos de C-B por HTTP(S). Entre Worker e hilo principal: mensajes con transferencia de fotogramas sin copia, y observaciones de vuelta |
| C-B Servidor estático | nginx sin privilegios en Docker (compose) | Sirve HTML, JS, CSS, WASM y modelos con MIME y caché correctos. Sin estado ni endpoints dinámicos | HTTP en localhost:8080 (TLS en proxy, en el futuro) |
| C-C Almacenamiento local | localStorage del navegador | Calibración, parámetros y perfil activo (FASE-04) | API síncrona del navegador desde C-A |
| C-D Sensórica remota (futuro) | Python en Docker | Captura RTSP o RGBD, inferencia y publicación de observaciones | WebSocket JSON hacia C-A con el contrato de observación (ADR-004) |

### 5.3 Nivel 3: componentes de C-A

| Componente | Capa | Responsabilidad | Puede depender de |
|---|---|---|---|
| dominio/membrana | Dominio | Campo de alturas; parámetros físicos y su validación (condición CFL, subpasos); solver de referencia en CPU; aplicación de excitaciones con perfil gaussiano; energía y desplazamiento máximo; reposo orgánico determinista con semilla (FASE-03). Define su propio tipo de entrada, la excitación (posición, amplitud, radio) | Nada |
| dominio/interaccion | Dominio | Observación y perturbación; estimadores de proximidad (tamaño aparente, profundidad); zonas e histéresis; espejo; cálculo de intensidad y radio; suavizado (filtro One Euro); asociación de identidades; tiempo de gracia; referencias y calibración de dos puntos (FASE-04) | Nada |
| aplicacion | Aplicación | Casos de uso: procesar observaciones (observaciones → perturbaciones activas), avanzar simulación (paso fijo con acumulador; perturbaciones → excitaciones → solver) y ciclo de frame (tick con el tiempo inyectado). Declara los puertos: fuente sensorial, solver de membrana, presentador, reloj, telemetría y, en FASE-04, almacén de configuración. Contiene el selector de perfil de calidad y el regulador de rendimiento (FASE-05) | dominio |
| adaptadores/sensorica | Adaptador | Fuente de cámara con MediaPipe (getUserMedia, HandLandmarker, FaceDetector, siempre el fotograma más reciente), fuente de puntero, fuente guionada (pruebas y demos) y, en el futuro, fuente remota por WebSocket | aplicacion, dominio, @mediapipe/tasks-vision |
| adaptadores/render | Adaptador | Presentador Three.js: destino de render del mundo, textura de alturas y compositor de refracción. Punto de extensión "Mundo", con el mundo de referencia (patrón de prueba) y, en FASE-05, el mundo de demostración 3D. Solver de GPU en ping-pong (FASE-03). Detector de capacidades gráficas (FASE-05) | aplicacion, dominio, three |
| adaptadores/ui | Adaptador | Panel de diagnóstico, avisos, pantalla completa, panel de parámetros y asistente de calibración (FASE-04) | aplicacion, dominio, lil-gui (FASE-04) |
| adaptadores/persistencia | Adaptador | Almacén local de configuración y perfiles con validación de versión (FASE-04) | aplicacion, dominio |
| arranque | Raíz de composición | Lee la configuración (URL o perfil), instancia los adaptadores, los inyecta en los casos de uso y arranca el bucle de requestAnimationFrame | Todos |

#### Contratos públicos entre módulos

- Observación (ADR-004), entregada por toda fuente sensorial:
  - identificador de la fuente;
  - marca de tiempo de captura (ms, reloj monotónico);
  - objetivo: mano, rostro o puntero;
  - identificador provisional del objetivo según el sensor (opcional);
  - posición en la imagen normalizada a [0, 1], con origen arriba a la izquierda y sin espejo aplicado;
  - tamaño aparente normalizado como fracción de la diagonal de la imagen (opcional);
  - profundidad métrica en metros (opcional; obligatoria si falta el tamaño aparente);
  - confianza en [0, 1].

  El espejo es una propiedad de la configuración de la fuente, no de la observación.
- Perturbación, producida por el dominio de interacción:
  - identificador estable;
  - objetivo;
  - posición en pantalla normalizada a [0, 1], ya con espejo;
  - proximidad en [0, 1];
  - zona: ninguna, influencia o contacto;
  - intensidad en [0, 1];
  - radio normalizado;
  - marca de tiempo.
- Excitación, entrada del dominio de membrana: posición, amplitud y radio en coordenadas normalizadas. La capa de aplicación traduce las perturbaciones en excitaciones, de modo que los dos módulos de dominio no se conocen.
- Campo de alturas: rejilla de ancho × alto configurables, con valores adimensionales. El presentador lo consume como textura: subida desde la CPU con el solver de referencia, o residente en GPU con el solver de GPU.

#### Regla de dependencia (explícita y verificada en el gate con dependency-cruiser y ESLint)

1. dominio/** no importa nada fuera de su propio módulo; dominio/membrana y dominio/interaccion no se importan entre sí.
2. aplicacion/** solo importa dominio/**.
3. Un adaptador no importa otro adaptador.
4. Solo arranque/** importa adaptadores/**; nadie importa arranque/**.
5. Las librerías externas (three, @mediapipe/tasks-vision, lil-gui) solo se importan desde adaptadores/**.
6. dominio/** y aplicacion/** no usan globales del navegador (window, document, navigator, performance, requestAnimationFrame, localStorage). El tiempo entra por el puerto de reloj.
7. No hay ciclos de dependencia.

### 5.4 Estructura del repositorio

```
cámaraSintec/
├─ web/                          C-A: aplicación web
│  ├─ src/dominio/membrana/
│  ├─ src/dominio/interaccion/
│  ├─ src/aplicacion/
│  ├─ src/adaptadores/{sensorica,render,ui,persistencia}/
│  ├─ src/arranque/
│  ├─ public/modelos/  public/wasm/      recursos de MediaPipe alojados en el propio servidor
│  ├─ tests/unit/  tests/aceptacion/    (.feature y pasos)  tests/e2e/
│  └─ herramientas/metricas/            cálculo de A y D y escritura de .flow/metrics/FASE-NN.json
├─ despliegue/                   Dockerfile y configuración de nginx
├─ compose.yaml                  punto de arranque único
└─ .flow/
```

Convenciones: identificadores del dominio en español y sin tildes (lenguaje ubicuo: Membrana, Observacion, Perturbacion, Excitacion, Proximidad, Zona); textos de la interfaz en español.

### 5.5 Entorno

- Runtime y gestor: Node.js 24 LTS; npm con package-lock.json.
- Versiones: fijadas exactas (sin ^ ni ~). Se usa la última estable publicada hace al menos dos semanas en el momento de instalar, y se registra en el retorno.
- Lenguaje: TypeScript en modo estricto (incluido noUncheckedIndexedAccess).
- Construcción: Vite.
- Dependencias de ejecución autorizadas: three, @mediapipe/tasks-vision y lil-gui (desde FASE-04).
- Dependencias de desarrollo autorizadas: vitest, @vitest/coverage-v8, @amiceli/vitest-cucumber (o quickpickle como respaldo, ADR-008), @playwright/test (Chromium), eslint 9 con typescript-eslint y dependency-cruiser.
- Contenedores: Docker Desktop con WSL2 y Compose v2. Imagen de construcción node:24-alpine; imagen de servicio nginxinc/nginx-unprivileged:alpine; ambas con etiqueta fija.
- Cualquier otra dependencia sigue las reglas de desvío o bloqueo del rol ejecutor.

## 6. Alternativas consideradas y descartadas

| Alternativa | Motivo del descarte | ADR |
|---|---|---|
| Inferencia en servidor con vídeo subido por WebRTC | GPU por cliente, 1 a 3 Mbps de subida por cliente, entre 40 y 150 ms de latencia añadida, imagen fuera del dispositivo | ADR-001 |
| Render en servidor con pixel streaming | Igual que la anterior, más el coste de codificación de vídeo | ADR-001 |
| Unity, Godot, TouchDesigner o Python con OpenGL | No llegan al navegador del cliente sin exportación web; licencias (TouchDesigner) | ADR-002 |
| Electron para las instalaciones | El navegador en modo kiosko cubre el caso (YAGNI) | ADR-002 |
| Proximidad por la coordenada Z de MediaPipe | Ruido excesivo, constatado en PIANOCAM | ADR-004 |
| YOLO de pose sobre ONNX Runtime Web; TensorFlow.js handpose | Más pesado o sin mantenimiento; sin detalle de la mano | ADR-005 |
| Física solo en shaders | No se puede probar con TDD ni medir con cobertura | ADR-006 |
| WebGL2 sin librería; Babylon.js; PixiJS; WebGPU nativo | Más código, más peso, solo 2D o peor soporte en pruebas sin interfaz gráfica | ADR-007 |
| Cucumber.js separado de Vitest | Dos ejecutores de pruebas y configuración duplicada | ADR-008 |

## 7. Patrones de diseño previstos

- Puertos y adaptadores (hexagonal): en toda la aplicación, para aislar el núcleo de sensores, GPU y navegador (ADR-003).
- Strategy:
  - solver de membrana (CPU de referencia o GPU), para la equivalencia probada y el respaldo;
  - estimador de proximidad (tamaño aparente o profundidad), para ser agnóstico del sensor;
  - Mundo, como punto de extensión para otros proyectos.
- Adapter: cada fuente sensorial traduce su API (MediaPipe, eventos de puntero, guion, WebSocket futuro) al contrato de observación.
- Observer: la fuente sensorial notifica observaciones a la aplicación mediante suscripción ligera (callback o EventTarget), sin librerías reactivas.
- Máquina de estados: la zona de cada objetivo (ninguna, influencia, contacto) con histéresis y tiempo de gracia, implementada como función de transición pura.
- Game loop de paso fijo con acumulador: desacopla la física de la frecuencia de pantalla y la hace determinista y estable.
- Doble búfer (ping-pong): estados t−1 y t del solver de GPU.
- Raíz de composición con inyección manual: arranque es el único lugar que conoce las implementaciones; no hay contenedor de inyección.
- Búferes preasignados (variante de object pool): perturbaciones, excitaciones y campos se reutilizan en el bucle caliente (RNF-09).

## 8. Estrategia de pruebas

- TDD obligatorio (rojo, verde, refactorización) en dominio, aplicación y en la lógica no visual de los adaptadores.
- Aceptación BDD: los escenarios de la sección 3 se escriben como archivos .feature en español y se ejecutan con vitest-cucumber sobre la capa de aplicación. Los adaptadores son falsos: fuente guionada, reloj manual y solver de CPU. Son deterministas y no necesitan navegador.
- Pruebas extremo a extremo (Playwright con Chromium sin interfaz gráfica):
  - RF-20 (sin permiso de cámara) y RF-21 (puntero);
  - RF-40 (refracción por regiones con tolerancia; nunca instantáneas exactas);
  - RF-50 y RF-51 contra el contenedor;
  - prueba de humo con la cámara falsa de Chromium (`--use-fake-device-for-media-stream`): la detección se inicializa sin errores.

  La fuente guionada se activa por parámetro de URL para que sean deterministas.
- Equivalencia numérica (FASE-03): el solver de GPU contra el de CPU en Chromium sin interfaz gráfica (SwiftShader), con tolerancia (RF-08).
- Rendimiento: mediciones manuales en el equipo de referencia con la instrumentación interna (RF-74). El JSON exportado se adjunta como evidencia al retorno.
- Cobertura mínima: 80 % de líneas en dominio y aplicación (es el valor del gate). Los adaptadores de render y de sensórica quedan fuera de la cobertura del gate y se cubren con las pruebas extremo a extremo.

## 9. Métricas de calidad objetivo

Umbrales (metricas_config.yml):

- complejidad ciclomática ≤ 10 por función;
- ≤ 20 líneas por función;
- cobertura ≥ 80 % en dominio y aplicación;
- D < 0.3 en todos los módulos;
- I < 0.5 en los módulos del núcleo;
- A > 0.5 en los módulos estables.

Herramientas (ADR-008): ESLint (complexity, max-lines-per-function sin contar líneas en blanco ni comentarios), dependency-cruiser (reglas e I) y un script del proyecto (A y D). Los shaders GLSL, los tests y los archivos de configuración quedan excluidos.

Clasificación de módulos para el JSON del gate:

| Módulo | nucleo | estable |
|---|---|---|
| dominio/membrana | true | true |
| dominio/interaccion | true | true |
| aplicacion | true | true |
| adaptadores/sensorica, adaptadores/render, adaptadores/ui, adaptadores/persistencia | false | false |
| arranque | false | false |

Riesgo conocido: un módulo de dominio algorítmico y estable (I ≈ 0) necesita A > 0.7 para que D sea menor que 0.3. Si un módulo de dominio supera D por su naturaleza concreta, el ejecutor lo reporta con su análisis y el planificador decide entre corrección y excepción mediante ADR.

### Ley de Amdahl (sensórica en Worker)

Supuesto: T_frame = T_inferencia + T_resto en el hilo principal (FASE-01). Si la inferencia de manos con GPU cuesta entre 10 y 15 ms y el resto entre 3 y 5 ms, la fracción migrable es P ≈ 0.7–0.8:

- Con N = 2 (hilo principal y Worker): S = 1 / ((1 − P) + P / 2) ≈ 1.54–1.67.
- Techo con la inferencia totalmente concurrente: 1 / (1 − P) ≈ 3.3–5.

Además, el render deja de sufrir los picos de inferencia, que es lo que pone en riesgo RNF-01.

Regla de decisión:

- FASE-01 debe medir P con profiling real.
- Si P ≥ 0.2 (techo ≥ 1.25), FASE-02 migra la sensórica a un Worker.
- Si P < 0.2, la migración no se justifica, se registra un ADR y la inferencia sigue en el hilo principal con limitación de frecuencia.

El solver de GPU no está sujeto a este análisis: es paralelismo de datos con P ≈ 1 sobre la rejilla.

Fase de cierre: los escenarios de carga HTTP de metricas_config.yml no aplican. El planificador los sustituirá por escenarios de rendimiento de render (sección 11 del rol).

## 10. Riesgos y mitigaciones

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | La proximidad estimada por tamaño aparente es imprecisa (varía con la persona y con la rotación de la mano) | Alta | Alto | Medida de tamaño robusta a la rotación (p. ej., máximo de dos segmentos de palma ortogonales); zonas graduales; histéresis; calibración de dos puntos (FASE-04); estimador intercambiable |
| R2 | tasks-vision no funciona en Web Worker o sin delegado GPU dentro del Worker | Media | Medio | Puerto de sensórica asíncrono; respaldo en el hilo principal con limitación de frecuencia; decisión medida con Amdahl en FASE-02 |
| R3 | Rendimiento insuficiente en equipos modestos | Media | Alto | Solver de CPU de respaldo; perfiles de calidad y regulador (FASE-05); resolución de simulación independiente de la de pantalla |
| R4 | Divergencia numérica de la simulación | Media | Alto | CFL como invariante del dominio; subpasos; límites de parámetros; pruebas de estabilidad de 60 s (RF-06) |
| R5 | getUserMedia exige contexto seguro fuera de localhost | Segura al desplegar | Medio | TLS en el proxy de despliegue (fuera de este plan); documentado en ADR-002 |
| R6 | La iluminación y el fondo degradan la detección | Media | Medio | Umbral de confianza (RF-18); panel de diagnóstico con vista de cámara; recomendaciones de instalación en la documentación |
| R7 | Pruebas visuales frágiles en Chromium sin interfaz gráfica | Media | Bajo | Comparación por regiones con tolerancia; semilla fija; reposo orgánico desactivable en modo prueba |
| R8 | La ruta del proyecto contiene un carácter no ASCII ("á"), lo que puede romper herramientas nativas en Windows | Baja | Medio | Detectarlo en FASE-01; si ocurre, bloqueo reportado (renombrar la carpeta es decisión del usuario) |
| R9 | El repositorio Git tiene la raíz en la carpeta padre (github/), con archivos de otros proyectos en el índice | Segura | Medio | Recomendación al usuario: inicializar un repositorio propio en cámaraSintec antes de FASE-01 (los commits los hace siempre el usuario) |
| R10 | Zona de dolor (D > 0.3) en módulos de dominio algorítmicos | Media | Bajo | Reporte con análisis; excepción mediante ADR si procede (sección 9) |
| R11 | Las versiones de las dependencias cambian entre fases | Baja | Bajo | Versiones exactas y package-lock.json; actualizaciones solo en fases planificadas |

## 11. Plan de fases

### FASE-01: Esqueleto andante (cámara → membrana → pantalla, con Docker)

- Objetivo: validar la arquitectura completa de extremo a extremo con la mínima anchura, incluidas la cadena de calidad y el despliegue.
- Alcance:
  - Proyecto web con TypeScript, Vite y la cadena de calidad: Vitest con cobertura, vitest-cucumber, Playwright, ESLint con umbrales, dependency-cruiser con las reglas de la sección 5.3 y el script de métricas.
  - dominio/membrana: solver de CPU de referencia (onda amortiguada con término restaurador, paso fijo, CFL, excitaciones gaussianas, energía) a resolución baja configurable. Reposo plano, sin reposo orgánico.
  - dominio/interaccion: estimadores por tamaño aparente y por profundidad con referencias por defecto; zonas sin histéresis; espejo; intensidad y radio.
  - aplicacion: puertos y casos de uso de procesar observaciones, avanzar simulación con acumulador y tick de frame.
  - Adaptadores:
    - sensórica: cámara con MediaPipe HandLandmarker en el hilo principal (hasta 2 manos), puntero y fuente guionada;
    - render: presentador Three.js con el mundo de referencia (patrón procedural de alto contraste), textura de alturas subida desde la CPU y compositor de refracción;
    - ui: aviso de cámara, pantalla completa y panel de diagnóstico básico (fps, perturbaciones, fuente).
  - Instrumentación del tiempo de inferencia y del tiempo de frame para medir P (Amdahl).
  - Despliegue: Dockerfile de varias etapas, configuración de nginx, compose.yaml y recursos de MediaPipe alojados en el propio servidor.
- Entregables: código en web/, despliegue/ y compose.yaml; .feature y pasos de RF-01 a RF-04, RF-10 a RF-13, RF-20, RF-21, RF-40, RF-50 y RF-51; .flow/metrics/FASE-01.json; informe de medición en el retorno.
- Métricas de éxito: gate APTO; cobertura ≥ 80 %; 0 violaciones de dependencias; medición de P disponible.
- DoD:
  - [ ] Escenarios RF-01, RF-02, RF-03, RF-04, RF-10, RF-11, RF-12, RF-13, RF-20, RF-21, RF-40, RF-50 y RF-51 implementados y en verde.
  - [ ] Pruebas unitarias en verde; cobertura de líneas ≥ 80 % en dominio y aplicación.
  - [ ] dependency-cruiser sin violaciones de la regla de dependencia; ESLint sin errores.
  - [ ] .flow/metrics/FASE-01.json generado según el esquema del gate y gate APTO (o violación reportada con análisis).
  - [ ] `docker compose up --build` sirve la aplicación en http://localhost:8080 y RF-50 y RF-51 pasan contra el contenedor; imagen ≤ 150 MB; build ≤ 5 min.
  - [ ] Prueba manual con webcam real en el equipo de referencia: al acercar la mano, la membrana se deforma en la posición espejada correspondiente. Evidencia: captura o vídeo breve más las lecturas del panel de diagnóstico.
  - [ ] Informe de medición en el retorno:
    - especificaciones del equipo de referencia;
    - fps medio y tiempo de frame p95 con detección activa;
    - tiempo medio y p95 de inferencia, y fracción P;
    - tamaño del JS inicial comprimido y transferencia total;
    - tiempo de arranque.
  - [ ] Auto-revisión del ejecutor realizada.

### FASE-02: Sensórica robusta y multipunto

- Objetivo: interacción fiable, fluida y de baja latencia con varias manos y el rostro.
- Alcance:
  - migración de la inferencia a un Web Worker con delegado GPU si P ≥ 0.2 (si no, ADR);
  - fotograma más reciente sin colas;
  - FaceDetector para el rostro y hasta 4 manos;
  - asociación de identidades, suavizado One Euro, histéresis, tiempo de gracia y umbral de confianza;
  - latencia de pipeline instrumentada;
  - panel de diagnóstico completo con vista de cámara y exportación JSON (RF-70 y RF-74).
- Entregables: escenarios RF-14 a RF-19 y RF-22; JSON de mediciones de una sesión de 60 s en el equipo de referencia.
- Métricas de éxito: RNF-01, RNF-02 y RNF-03 cumplidos.
- DoD:
  - [ ] RF-14 a RF-19 y RF-22 en verde; los escenarios de FASE-01 siguen en verde.
  - [ ] RNF-01 (p95 ≤ 16.7 ms), RNF-02 (≥ 25 Hz) y RNF-03 (p95 ≤ 50 ms) cumplidos, con el JSON de mediciones como evidencia.
  - [ ] Decisión sobre el Worker conforme a la regla de Amdahl, con P medido y adjunto.
  - [ ] Cobertura ≥ 80 %; gate APTO; 0 violaciones de dependencias.
  - [ ] Auto-revisión realizada.

### FASE-03: Membrana en GPU y refracción de calidad

- Objetivo: la membrana a alta resolución y con calidad visual final.
- Alcance:
  - solver de GPU en ping-pong que implementa el mismo puerto que el de CPU;
  - prueba de equivalencia;
  - subpasos y CFL;
  - reposo orgánico determinista con semilla;
  - refracción con normales, realce especular sutil y aberración cromática parametrizable;
  - respaldo automático a CPU;
  - bucle caliente sin asignaciones.
- Entregables: escenarios RF-05 a RF-09; perfil de rendimiento de 60 s.
- Métricas de éxito: RNF-01 con RNF-04 (≥ 512 celdas) y RNF-09.
- DoD:
  - [ ] RF-05 a RF-09 en verde; los escenarios anteriores siguen en verde.
  - [ ] RNF-01 cumplido con la simulación a ≥ 512 celdas en el eje mayor (RNF-04), con mediciones como evidencia.
  - [ ] RNF-09: perfil de 60 s sin pausas de recolección de basura > 5 ms.
  - [ ] Cobertura ≥ 80 %; gate APTO.
  - [ ] Auto-revisión realizada.

### FASE-04: Calibración y ajuste en vivo

- Objetivo: adaptar la interacción a cada persona, equipo y lugar sin tocar código.
- Alcance:
  - asistente de calibración de dos puntos para mano y rostro;
  - panel de parámetros con lil-gui (física, zonas, suavizado y render);
  - persistencia local;
  - perfiles JSON versionados con exportación, importación, validación y restablecimiento.
- Entregables: escenarios RF-30 a RF-34; el esquema del perfil documentado en el código.
- DoD:
  - [ ] RF-30 a RF-34 en verde; los escenarios anteriores siguen en verde.
  - [ ] La calibración real en el equipo de referencia mejora la experiencia, con las referencias antes y después como evidencia en el retorno.
  - [ ] Cobertura ≥ 80 %; gate APTO.
  - [ ] Auto-revisión realizada.

### FASE-05: Rendimiento adaptativo, mundo de demostración 3D y estabilidad

- Objetivo: aprovechar los recursos de cada equipo y dejar el sistema listo para instalarse en otros.
- Alcance:
  - detector de capacidades;
  - perfiles de calidad y regulador con histéresis;
  - mundo de demostración 3D procedural (escena con profundidad, iluminación y deriva lenta de cámara) en el punto de extensión Mundo;
  - prueba de estabilidad de 60 minutos;
  - mediciones de arranque y peso.
- Entregables: escenarios RF-60 y RF-61; informe de estabilidad; informe de rendimiento con el perfil por nivel de calidad.
- DoD:
  - [ ] RF-60 y RF-61 en verde; los escenarios anteriores siguen en verde.
  - [ ] RNF-06, RNF-07 y RNF-08 cumplidos, con evidencia.
  - [ ] El mundo de demostración se sustituye por el de referencia cambiando solo la configuración (la extensibilidad queda demostrada).
  - [ ] Cobertura ≥ 80 %; gate APTO.
  - [ ] Auto-revisión realizada.

### Cierre

- Documentación: prompt para el documentador. Incluye la arquitectura con diagramas, la guía de instalación (Docker y kiosko), la guía de calibración y la guía para crear un mundo nuevo y un sensor nuevo.
- Análisis: el planificador ajusta metricas_config.yml (escenarios de render en lugar de HTTP) y el analizador ejecuta el análisis en su rama.

### Trabajo futuro (fuera de este plan; requerirá nuevos ADR)

- Servicio de sensórica remota en Python (RTSP o RGBD) dentro del compose, publicando el contrato de observación por WebSocket.
- Adaptador RGBD real.
- Despliegue en la nube con TLS y CDN.
- Configuración por cliente (multi-tenant).
- WebGPU.
- Paralaje por cabeza.

## Glosario (lenguaje ubicuo)

- Membrana: plano translúcido simulado que cubre la pantalla.
- Campo de alturas: rejilla con el desplazamiento de la membrana en cada celda.
- Excitación: fuerza aplicada al campo (posición, amplitud y radio).
- Observación: dato de un sensor sobre un objetivo, en el formato del contrato común.
- Perturbación: interpretación en el dominio de una o más observaciones de un mismo objetivo (zona, intensidad, radio, identidad).
- Proximidad: cercanía adimensional en el rango 0 a 1.
- Zona: ninguna, influencia o contacto.
- Referencias: tamaños o profundidades que delimitan las zonas.
- Calibración: proceso que fija las referencias.
- Tolerancia de reposo: desplazamiento máximo que se considera calma.
- Reposo orgánico: micro-ondulación de baja amplitud en ausencia de perturbaciones.
- Mundo: escena que se ve a través de la membrana; es intercambiable.
- Solver: integrador numérico del campo de alturas.
- Fuente sensorial: adaptador que produce observaciones.
- Perfil: conjunto exportable de calibración y parámetros.
