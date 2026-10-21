#!/usr/bin/env python3
# verificar_fase.py - Gate mecanico del kit .flow
#
# Uso:
#   python .flow/tools/verificar_fase.py FASE-01
#   python .flow/tools/verificar_fase.py --demo      (autocomprobacion del script)
#
# Compara .flow/metrics/<FASE>.json con los umbrales de
# .flow/tools/metricas_config.yml y emite un veredicto APTO / NO APTO.
# Codigos de salida: 0 = APTO, 1 = NO APTO, 2 = error de uso o de datos.
#
# Lo ejecuta el ejecutor al cerrar cada fase (y pega la salida en su retorno);
# el desarrollador y el planificador pueden re-ejecutarlo en cualquier momento.
#
# Esquema canonico de .flow/metrics/FASE-NN.json (lo escribe el ejecutor):
# {
#   "fase": "FASE-01",
#   "fecha": "AAAA-MM-DD",
#   "complejidad_ciclomatica_max": 7,        # maximo observado en la fase
#   "lineas_por_metodo_max": 18,             # maximo observado
#   "cobertura": 0.86,                       # fraccion 0..1 en logica de negocio
#   "modulos": [                             # opcional: si hay datos de dependencias
#     {"nombre": "dominio", "I": 0.25, "A": 0.5, "D": 0.25,
#      "nucleo": true,                       # true = se le exige I < inestabilidad_max
#      "estable": true}                      # true = se le exige A > abstraccion_min
#   ],
#   "fuentes": ["rutas de las salidas crudas de las herramientas"]
# }
# Campos ausentes se reportan como NO VERIFICADO: no bloquean el veredicto,
# pero quedan listados para que el planificador los vea.

import json
import re
import sys

CONFIG = ".flow/tools/metricas_config.yml"
METRICS_DIR = ".flow/metrics"

UMBRAL_KEYS = [
    "inestabilidad_max",
    "abstraccion_min",
    "distancia_max",
    "complejidad_ciclomatica_max",
    "lineas_por_metodo_max",
    "cobertura_min",
]


def leer_umbrales(ruta):
    # Lectura deliberadamente simple del YAML: los umbrales son claves unicas
    # de valor numerico, asi que basta un barrido linea a linea (sin PyYAML).
    umbrales = {}
    # utf-8-sig: tolera el BOM que anaden algunos editores y PowerShell en Windows
    with open(ruta, encoding="utf-8-sig") as f:
        for linea in f:
            m = re.match(r"^\s*([a-z_]+)\s*:\s*([0-9]*\.?[0-9]+)\s*(#.*)?$", linea)
            if m and m.group(1) in UMBRAL_KEYS:
                umbrales[m.group(1)] = float(m.group(2))
    return umbrales


def evaluar(datos, umbrales):
    # Devuelve (violaciones, no_verificado, comprobaciones_ok) como listas de textos.
    viol, nover, ok = [], [], []

    def check(nombre, valor, umbral, cmp_menor_igual):
        if umbral is None:
            nover.append("%s: sin umbral en la configuracion" % nombre)
            return
        if valor is None:
            nover.append("%s: sin dato en el JSON de la fase" % nombre)
            return
        cumple = valor <= umbral if cmp_menor_igual else valor >= umbral
        linea = "%s = %s (umbral %s %s)" % (
            nombre, valor, "<=" if cmp_menor_igual else ">=", umbral)
        (ok if cumple else viol).append(linea)

    check("complejidad_ciclomatica_max", datos.get("complejidad_ciclomatica_max"),
          umbrales.get("complejidad_ciclomatica_max"), True)
    check("lineas_por_metodo_max", datos.get("lineas_por_metodo_max"),
          umbrales.get("lineas_por_metodo_max"), True)
    check("cobertura", datos.get("cobertura"),
          umbrales.get("cobertura_min"), False)

    modulos = datos.get("modulos")
    if not modulos:
        nover.append("modulos (I, A, D): sin datos de dependencias en el JSON")
    else:
        for mod in modulos:
            nombre = mod.get("nombre", "sin_nombre")
            check("D del modulo %s" % nombre, mod.get("D"),
                  umbrales.get("distancia_max"), True)
            if mod.get("nucleo"):
                check("I del modulo %s (nucleo)" % nombre, mod.get("I"),
                      umbrales.get("inestabilidad_max"), True)
            if mod.get("estable"):
                check("A del modulo %s (estable)" % nombre, mod.get("A"),
                      umbrales.get("abstraccion_min"), False)
    return viol, nover, ok


def demo():
    umbrales = {"complejidad_ciclomatica_max": 10, "lineas_por_metodo_max": 20,
                "cobertura_min": 0.8, "distancia_max": 0.3,
                "inestabilidad_max": 0.5, "abstraccion_min": 0.5}
    apto = {"complejidad_ciclomatica_max": 7, "lineas_por_metodo_max": 18,
            "cobertura": 0.86,
            "modulos": [{"nombre": "dominio", "I": 0.25, "A": 0.5, "D": 0.25,
                         "nucleo": True, "estable": True}]}
    v, n, o = evaluar(apto, umbrales)
    assert not v and len(o) == 6, (v, o)
    noapto = dict(apto, cobertura=0.5)
    v, _, _ = evaluar(noapto, umbrales)
    assert len(v) == 1 and "cobertura" in v[0], v
    incompleto = {"cobertura": 0.9}
    v, n, _ = evaluar(incompleto, umbrales)
    assert not v and len(n) == 3, (v, n)
    print("demo: las autocomprobaciones del gate pasan")


def main():
    if len(sys.argv) != 2:
        print("Uso: python .flow/tools/verificar_fase.py FASE-NN  (o --demo)")
        return 2
    if sys.argv[1] == "--demo":
        demo()
        return 0

    fase = sys.argv[1]
    ruta_json = fase if fase.endswith(".json") else "%s/%s.json" % (METRICS_DIR, fase)
    try:
        umbrales = leer_umbrales(CONFIG)
    except OSError as e:
        print("ERROR: no se pudo leer %s (%s)" % (CONFIG, e))
        return 2
    try:
        with open(ruta_json, encoding="utf-8-sig") as f:
            datos = json.load(f)
    except OSError:
        print("ERROR: no existe %s. El ejecutor debe generarlo al cerrar la fase." % ruta_json)
        return 2
    except json.JSONDecodeError as e:
        print("ERROR: %s no es JSON valido (%s)" % (ruta_json, e))
        return 2

    viol, nover, ok = evaluar(datos, umbrales)

    print("== Gate .flow | fase: %s | datos: %s ==" % (datos.get("fase", fase), ruta_json))
    for linea in ok:
        print("[ok]           " + linea)
    for linea in nover:
        print("[no verificado] " + linea)
    for linea in viol:
        print("[VIOLACION]    " + linea)
    print()
    if viol:
        print("VEREDICTO: NO APTO (%d violaciones)" % len(viol))
        print("Salidas posibles: prompt de correccion, o excepcion justificada")
        print("que el planificador registre como ADR.")
        return 1
    print("VEREDICTO: APTO" + (" (con %d puntos no verificados)" % len(nover) if nover else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
