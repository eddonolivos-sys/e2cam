# Registro de Decisiones Técnicas (ADR)

Solo el planificador escribe en este archivo. Cada decisión arquitectónica importante se registra como un ADR (Architecture Decision Record, formato de Michael Nygard). Las entradas se añaden al final; un ADR nunca se edita en su sustancia: si la decisión cambia, se escribe un nuevo ADR que la reemplaza y en el antiguo solo se actualiza el campo Estado.

Estados posibles: Propuesta, Aceptada, Reemplazada por ADR-XXX, Obsoleta.

Formato de cada entrada:

## ADR-NNN: [título de la decisión]

- Estado: [Propuesta / Aceptada / Reemplazada por ADR-XXX / Obsoleta]
- Fecha: [AAAA-MM-DD]
- Contexto: [situación, fuerzas en juego, restricciones que obligan a decidir]
- Decisión: [qué se decidió, en voz activa]
- Consecuencias: [efectos positivos y negativos; qué se vuelve más fácil y qué más difícil; impacto en métricas o fases]

<!-- Ejemplo de referencia:

## ADR-001: Persistencia con SQLite en desarrollo y PostgreSQL en producción

- Estado: Aceptada
- Fecha: 2026-01-15
- Contexto: el catálogo tiene volumen bajo, el equipo es pequeño y se necesita
  fricción mínima en el entorno local sin renunciar a un motor robusto en producción.
- Decisión: usar SQLite en desarrollo y PostgreSQL en producción, tras una
  interfaz de repositorio que aísle el dialecto SQL.
- Consecuencias: el arranque local no requiere servicios externos; la capa de
  infraestructura debe evitar SQL específico de un motor; se añade una tarea de
  verificación de compatibilidad antes del despliegue.
-->

<!-- Las entradas reales comienzan debajo de esta línea. -->

## ADR-001: Procesamiento en el borde (cliente); la nube solo distribuye estáticos

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: el sistema será la base de otros proyectos y debe poder servir a muchos clientes desde la nube, ejecutarse en un PC local o, en el futuro, recibir cámaras externas. La interacción exige baja latencia (presupuesto de 100 ms de movimiento a imagen) y procesa imagen de personas. Se evaluaron tres ubicaciones para la inferencia y el render: cliente, servidor con inferencia remota (vídeo subido por WebRTC) y servidor con render remoto (pixel streaming).
- Decisión: la captura, la inferencia de visión, la simulación física y el render se ejecutan en el dispositivo del cliente. El servidor es un distribuidor de recursos estáticos sin estado (aplicación, WASM y modelos). Ninguna imagen sale del dispositivo. La sensórica remota (cámaras RTSP o RGBD conectadas a otro equipo) se contempla como un adaptador futuro que entregará observaciones ya procesadas, nunca vídeo, mediante el contrato de ADR-004.
- Consecuencias: el coste de servidor por cliente es prácticamente nulo y el escalado es horizontal y trivial (CDN o réplicas de un servidor estático); se elimina el tiempo de ida y vuelta de red del bucle de interacción; la privacidad queda garantizada por diseño. A cambio, el rendimiento depende del hardware del cliente, lo que obliga a perfiles de calidad adaptativos (ADR-009) y a fijar un equipo de referencia para los requisitos no funcionales. La inferencia en servidor queda descartada: exigiría GPU por cliente, ancho de banda de subida de 1 a 3 Mbps por cliente y añadiría entre 40 y 150 ms de latencia.

## ADR-002: Plataforma web con TypeScript; Chromium como navegador de referencia

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: el sistema debe funcionar como aplicación web con la cámara del cliente y también en un PC local o instalación. Alternativas evaluadas: motor nativo (Unity, Godot), TouchDesigner, y Python con OpenGL. Ninguna de ellas llega al navegador del cliente sin una exportación web que reintroduce las mismas restricciones, y TouchDesigner añade licencias por equipo.
- Decisión: aplicación de página única en TypeScript (modo estricto) con Vite como herramienta de construcción, ejecutada en el navegador. Navegadores de aceptación: Chrome y Edge estables actuales en Windows 11. Firefox y Safari se consideran de mejor esfuerzo, sin criterio de aceptación. Las instalaciones locales usan el mismo artefacto en un navegador en modo kiosko; no se empaqueta con Electron.
- Consecuencias: un único artefacto cubre web, PC local e instalación; acceso a GPU para render (WebGL2) y para inferencia (delegado GPU de MediaPipe). getUserMedia exige contexto seguro: localhost lo es, pero cualquier otro host requiere TLS, lo que se resolverá en el proxy de despliegue cuando se publique fuera del equipo local. La lógica de dominio en TypeScript puro se puede probar en Node sin navegador.

## ADR-003: Arquitectura hexagonal (puertos y adaptadores) con regla de dependencia hacia el dominio

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: el objetivo exige separar la sensórica, la simulación física y el render, y el sistema será la base de otros proyectos con otros sensores y otros mundos visuales. Hay que poder sustituir cualquier extremo sin tocar el núcleo, y probar la física y la interacción sin cámara ni GPU.
- Decisión: se organiza la aplicación en cinco capas. El dominio contiene la física de la membrana y las reglas de interacción. La aplicación contiene la orquestación y los puertos. Los adaptadores contienen la sensórica, el render, la interfaz y la persistencia. El arranque es la raíz de composición. Las dependencias apuntan siempre hacia el dominio: el dominio no importa nada externo (ni librerías, ni APIs del navegador); la aplicación solo importa el dominio; los adaptadores no se importan entre sí; solo el arranque conoce a todos. El tiempo se inyecta mediante un puerto de reloj. La regla se verifica mecánicamente con dependency-cruiser en el gate de cada fase.
- Consecuencias: el núcleo es determinista y se prueba en Node con adaptadores falsos; sensores, solvers y mundos son intercambiables. Se paga con más interfaces y más cableado en la raíz de composición. Los módulos de dominio puramente algorítmicos pueden caer en la zona de dolor (D alto con I bajo); si ocurre, se evaluará una excepción mediante un nuevo ADR.

## ADR-004: Contrato de observación agnóstico del sensor y proximidad normalizada

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: el sistema debe funcionar con cualquier cámara (RGB hoy; RGBD u otros sensores mañana). Con una cámara RGB monocular no hay medida métrica fiable de la distancia: solo referencias relativas al tamaño aparente. En PIANOCAM se constató que la coordenada Z de MediaPipe es demasiado ruidosa para usarla como señal principal.
- Decisión: toda fuente sensorial entrega observaciones con un contrato común: objetivo (mano, rostro o puntero), posición normalizada en la imagen, tamaño aparente normalizado (opcional), profundidad métrica (opcional, obligatoria si no hay tamaño), confianza y marca de tiempo de captura. El dominio convierte observaciones en perturbaciones mediante un estimador de proximidad intercambiable (Strategy): por tamaño aparente, con referencias por defecto y calibrables, para RGB; por profundidad, para RGBD. La proximidad del dominio es adimensional en el rango 0 a 1. La interacción se divide en zonas (ninguna, influencia y contacto) con umbrales y parámetros ajustables en vivo.
- Consecuencias: añadir un sensor equivale a escribir un adaptador que rellene el contrato, sin tocar el núcleo. El futuro servicio de sensórica remota publicará exactamente este contrato. Como la proximidad no es métrica, la experiencia depende de una buena calibración: por eso existe una fase dedicada a calibración y ajuste (FASE-04). Las referencias por defecto deben ser razonables para un usuario adulto a la distancia típica de un monitor.

## ADR-005: Detección con MediaPipe Tasks Vision, modelos alojados en el propio servidor

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: se necesita detectar manos y rostro en tiempo real en el navegador, con aceleración por GPU. Alternativas evaluadas: YOLO de pose sobre ONNX Runtime Web (más pesado y sin detalle de la mano), los antiguos paquetes de manos de MediaPipe (obsoletos) y TensorFlow.js handpose (sin mantenimiento).
- Decisión: se usa @mediapipe/tasks-vision: HandLandmarker para manos y FaceDetector para rostro (más ligero que FaceLandmarker y suficiente para obtener posición y tamaño). Se usa el delegado GPU, con respaldo en CPU. El WASM y los modelos se alojan en el mismo origen que la aplicación; no hay dependencias de CDN de terceros en tiempo de ejecución. La inferencia procesa siempre el fotograma más reciente y descarta los atrasados, sin colas. En FASE-01 se ejecuta en el hilo principal; en FASE-02 se migrará a un Web Worker si la medición de Amdahl lo justifica.
- Consecuencias: funciona sin conexión una vez cargada, con versión de modelo controlada y sin fugas de datos a terceros; la primera carga transfiere varios megabytes de modelos y WASM, que quedan cacheables. Riesgo conocido: la compatibilidad de tasks-vision con Web Workers y con el delegado GPU dentro de un worker no está garantizada; el puerto de sensórica es asíncrono para que el hilo de ejecución sea un detalle del adaptador.

## ADR-006: Física de membrana como ecuación de onda amortiguada; referencia en CPU y producción en GPU

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: la membrana debe mostrar reposo con tensión superficial, deformación local, ondas expansivas y retorno amortiguado a la calma, a alta resolución y 60 fps o más. La física en shaders es rápida pero difícil de probar con TDD y de medir con cobertura.
- Decisión: la membrana se modela como un campo de alturas regido por una ecuación de onda 2D con amortiguamiento viscoso y un término restaurador hacia el reposo. Se integra con un esquema explícito de paso fijo y subpasos, y la condición de estabilidad CFL es un invariante del dominio. Habrá dos implementaciones del mismo puerto de solver (Strategy): una de referencia en CPU, en TypeScript puro, dentro del dominio, y una de producción en GPU, con texturas en ping-pong, dentro del adaptador de render. La equivalencia entre ambas se verifica con un test numérico con tolerancia. La simulación avanza con paso fijo, desacoplada de la frecuencia de pantalla mediante un acumulador.
- Consecuencias: el comportamiento físico se especifica y prueba con TDD y BDD en Node; la GPU aporta la resolución y el rendimiento; el solver de CPU sirve además de respaldo cuando no hay texturas de coma flotante renderizables. Mantener dos implementaciones cuesta un test de equivalencia por fase que toque la física. Los shaders GLSL quedan fuera de las métricas estáticas y su corrección se cubre con ese test.

## ADR-007: Render con Three.js sobre WebGL2; el mundo es un puerto intercambiable

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: hay que renderizar un mundo 3D, simular la membrana en GPU y componer la refracción a pantalla completa. Alternativas evaluadas: WebGL2 sin librería (más control, mucho más código), Babylon.js (más pesado), PixiJS (solo 2D) y WebGPU nativo, con buen soporte en navegadores pero peor soporte en Chromium sin interfaz gráfica para tests automáticos.
- Decisión: se usa Three.js con WebGLRenderer (WebGL2) y shaders GLSL propios. El mundo se dibuja en un destino de render fuera de pantalla; el solver produce la textura de alturas; una pasada de composición a pantalla completa desplaza el muestreo del mundo según las normales del campo de alturas (aproximación de la refracción en espacio de pantalla) y añade un realce especular sutil. El mundo es un puerto: cualquier proyecto futuro aporta su propio mundo sin tocar la membrana. WebGPU queda diferido hasta que el profiling lo justifique, mediante un ADR nuevo.
- Consecuencias: tiempo de desarrollo bajo para mundos 3D ricos y gran ecosistema; se puede probar en Chromium sin interfaz gráfica con SwiftShader. Three.js se convierte en dependencia de los adaptadores de render, nunca del dominio. Requiere la extensión de texturas de coma flotante renderizables para el solver en GPU; sin ella se usa el solver de CPU a menor resolución.

## ADR-008: Herramientas de prueba y de métricas estáticas para TypeScript

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: el flujo exige TDD, aceptación BDD en Gherkin y un gate de métricas (complejidad, líneas por método, cobertura, I, A, D). La configuración de métricas por defecto del kit está pensada para Python y servicios HTTP.
- Decisión: Vitest para pruebas unitarias y de integración, con cobertura v8. Gherkin en español (archivos .feature) ejecutado con @amiceli/vitest-cucumber sobre la capa de aplicación con adaptadores falsos (fuente guionada, reloj manual, solver de CPU); si es incompatible con la versión fijada de Vitest, el respaldo es quickpickle, registrado como desvío. Playwright con Chromium para pruebas extremo a extremo, usando la cámara falsa de Chromium y una fuente guionada para que sean deterministas. ESLint con typescript-eslint para complejidad ciclomática (máximo 10) y líneas por función (máximo 20, sin contar blancos ni comentarios). dependency-cruiser para las reglas de dependencia y la inestabilidad (I). Un script del proyecto calcula la abstracción (A) y la distancia (D) por módulo y escribe .flow/metrics/FASE-NN.json. Para A se cuentan como abstractos las interfaces, los alias de tipo y las clases abstractas; como concretos, las clases y las funciones exportadas de nivel superior. La cobertura del gate es la de líneas de dominio y aplicación.
- Consecuencias: un único ejecutor de pruebas para unitarias y BDD, en Node y rápido; las pruebas visuales se basan en regiones y tolerancias, no en instantáneas exactas, para no ser frágiles. Los adaptadores de render y de sensórica quedan fuera de la cobertura del gate y se cubren con las pruebas extremo a extremo. Los escenarios de carga HTTP de metricas_config.yml no aplican; se sustituirán por escenarios de rendimiento de render en la fase de cierre.

## ADR-009: Contenerización con Docker de un servidor estático sin estado y calidad adaptativa en el cliente

- Estado: Aceptada
- Fecha: 2026-10-21
- Contexto: el usuario quiere arrancar todo con Docker y prepararse para escalar en la nube. También quiere aprovechar todos los recursos de cada equipo y poder instalar el sistema en equipos distintos. Por ADR-001, el servidor no procesa nada.
- Decisión: un Dockerfile de varias etapas construye la aplicación con Node y la sirve con nginx en una imagen sin privilegios, con el tipo MIME correcto para WASM y cabeceras de caché para recursos con hash. compose.yaml es el único punto de arranque (docker compose up --build). El servicio de sensórica remota en Python no se construye ahora: queda reservado como futuro servicio del mismo compose. En el cliente, la aplicación detecta sus capacidades al arrancar y elige un perfil de calidad: resolución de la simulación, densidad de píxeles, número de objetivos y delegado de inferencia. Después, un regulador de rendimiento lo ajusta en ejecución para sostener la frecuencia objetivo.
- Consecuencias: el despliegue es reproducible y escalable horizontalmente sin estado; la misma imagen sirve para pruebas locales y nube. La calidad visual varía según el equipo, por diseño. El TLS fuera de localhost queda pendiente de la decisión de despliegue en la nube, que no forma parte de este plan. La calidad adaptativa se implementa en FASE-05; hasta entonces el perfil es fijo y configurable.
