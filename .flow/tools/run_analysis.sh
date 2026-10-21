#!/usr/bin/env bash
# run_analysis.sh - Lanzador de analisis del kit .flow
#
# Uso:      bash .flow/tools/run_analysis.sh   (desde la raiz del proyecto)
# Requiere: bash (en Windows: Git Bash o WSL). Las herramientas concretas
#           dependen del stack; ver .flow/tools/metricas_config.yml.
#
# Que hace:
#   1. Comprueba que herramientas estan disponibles y lo reporta.
#   2. Analisis estatico (radon, dependency-cruiser) -> .flow/analisis/datos/
#   3. Forense: entropia de cambios y churn desde el historial Git
#      (code-maat si esta instalado; si no, git log --numstat como alternativa).
#   4. Tests con cobertura, si pytest esta disponible.
#   5. Hooks comentados para pruebas de rendimiento (locust, k6, benchmark).
#   6. Graficos: invoca .flow/tools/generar_graficos.py si existe.
#   7. Crea el esqueleto del informe si aun no existe.
#
# Este script es un punto de partida: el analizador debe adaptarlo al proyecto.
# Esa adaptacion es instrumentacion de la rama de analisis y no se fusiona a main.

set -euo pipefail

CONFIG=".flow/tools/metricas_config.yml"
DATOS_DIR=".flow/analisis/datos"
INFORME=".flow/analisis/informe_analisis.md"
FECHA="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$DATOS_DIR"

echo "== Kit .flow: analisis =="
echo "Configuracion:   $CONFIG"
echo "Salida de datos: $DATOS_DIR"
echo

# ---------------------------------------------------------------------------
# 0. Inventario de herramientas
# ---------------------------------------------------------------------------

check_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "[ok]      $1"
    return 0
  else
    echo "[falta]   $1  ($2)"
    return 1
  fi
}

echo "-- Herramientas --"
HAS_RADON=0;  check_tool radon  "pip install radon" && HAS_RADON=1
HAS_NPX=0;    check_tool npx    "instalar Node.js" && HAS_NPX=1
HAS_PYTEST=0; check_tool pytest "pip install pytest pytest-cov" && HAS_PYTEST=1
HAS_GIT=0;    check_tool git    "instalar Git" && HAS_GIT=1
HAS_MAAT=0;   check_tool maat   "code-maat (opcional; hay alternativa con git log)" && HAS_MAAT=1
echo

# ---------------------------------------------------------------------------
# 1. Analisis estatico
# ---------------------------------------------------------------------------

if [ "$HAS_RADON" -eq 1 ] && [ -d src ]; then
  echo "[estatico] radon: complejidad ciclomatica y mantenibilidad"
  radon cc src -s -j > "$DATOS_DIR/radon_cc_$FECHA.json" || true
  radon mi src -j > "$DATOS_DIR/radon_mi_$FECHA.json" || true
fi

if [ -f package.json ] && [ "$HAS_NPX" -eq 1 ]; then
  echo "[estatico] dependency-cruiser: grafo de dependencias"
  npx --yes dependency-cruiser src --output-type json \
    > "$DATOS_DIR/depcruise_$FECHA.json" || echo "[estatico] dependency-cruiser fallo - omitido"
fi

# Java (jQAssistant): descomentar y adaptar si aplica
# ./mvnw jqassistant:scan jqassistant:analyze

# ---------------------------------------------------------------------------
# 2. Forense: churn y entropia de cambios (requiere historial Git)
# ---------------------------------------------------------------------------

if [ "$HAS_GIT" -eq 1 ] && git rev-parse --git-dir >/dev/null 2>&1; then
  echo "[forense] extrayendo historial de cambios"
  git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' \
    > "$DATOS_DIR/git_log_$FECHA.log" || true

  if [ "$HAS_MAAT" -eq 1 ]; then
    echo "[forense] code-maat: churn por entidad"
    maat -l "$DATOS_DIR/git_log_$FECHA.log" -c git2 -a entity-churn \
      > "$DATOS_DIR/churn_$FECHA.csv" || echo "[forense] code-maat fallo - usar alternativa"
  else
    echo "[forense] alternativa sin code-maat: conteo de cambios por archivo"
    # Cuenta cuantas veces aparece cada archivo en el log (churn aproximado).
    # Con estas frecuencias se calcula la entropia H = -sum(p_i * log2(p_i)).
    git log --all --numstat --pretty=format: \
      | awk 'NF==3 {print $3}' | sort | uniq -c | sort -rn \
      > "$DATOS_DIR/churn_$FECHA.txt" || true
  fi
else
  echo "[forense] sin historial Git disponible - omitido"
fi

# ---------------------------------------------------------------------------
# 3. Tests y cobertura
# ---------------------------------------------------------------------------

if [ "$HAS_PYTEST" -eq 1 ]; then
  echo "[dinamico] pytest con cobertura"
  pytest -q --cov=src --cov-report=json:"$DATOS_DIR/cobertura_$FECHA.json" \
    || echo "[dinamico] hay tests en rojo: corregir antes de medir rendimiento"
fi

# ---------------------------------------------------------------------------
# 4. Rendimiento (ejemplos; descomentar y adaptar a los escenarios del YAML)
# ---------------------------------------------------------------------------

# Micro-benchmarks (pytest-benchmark):
# pytest tests/benchmarks -q --benchmark-json="$DATOS_DIR/benchmark_$FECHA.json"

# Carga HTTP (locust, sin interfaz; usuarios/tiempo segun metricas_config.yml):
# locust -f tests/carga/locustfile.py --headless -u 10 -r 2 -t 60s \
#   --csv "$DATOS_DIR/locust_carga_normal_$FECHA"

# Carga HTTP (k6):
# k6 run tests/carga/script.js --summary-export "$DATOS_DIR/k6_$FECHA.json"

# Memoria (Python):
# python -m memory_profiler script_a_medir.py > "$DATOS_DIR/memoria_$FECHA.txt"

# ---------------------------------------------------------------------------
# 5. Graficos (si existe el script del analizador)
# ---------------------------------------------------------------------------

if [ -f .flow/tools/generar_graficos.py ] && command -v python >/dev/null 2>&1; then
  echo "[graficos] generando PNG con generar_graficos.py"
  python .flow/tools/generar_graficos.py "$DATOS_DIR" || echo "[graficos] fallo - revisar script"
else
  echo "[graficos] sin script de graficos - los datos quedan listos para graficar"
fi

# ---------------------------------------------------------------------------
# 6. Esqueleto del informe
# ---------------------------------------------------------------------------

if [ ! -f "$INFORME" ]; then
  mkdir -p "$(dirname "$INFORME")"
  {
    echo "# Informe de analisis"
    echo
    echo "## 1. Resumen ejecutivo"
    echo "## 2. Metodologia (herramientas, versiones, repeticiones, entorno, limitaciones)"
    echo "## 3. Resultados estaticos (I, A, D, complejidad vs umbrales)"
    echo "## 4. Resultados dinamicos (latencias, throughput, memoria vs NFR)"
    echo "## 5. Forense (entropia de cambios, hotspots priorizados)"
    echo "## 6. Amdahl (si aplica)"
    echo "## 7. Metricas DORA adaptadas (desde handoff_log.md)"
    echo "## 8. Conclusiones y recomendaciones priorizadas"
    echo "## 9. Anexos (datos crudos y scripts de reproduccion)"
  } > "$INFORME"
  echo "[informe] esqueleto creado en $INFORME"
fi

echo
echo "Datos crudos en: $DATOS_DIR"
echo "Siguiente paso: calcular metricas derivadas (I, A, D, entropia, hotspots,"
echo "Amdahl, DORA) segun $CONFIG y completar el informe: $INFORME"
