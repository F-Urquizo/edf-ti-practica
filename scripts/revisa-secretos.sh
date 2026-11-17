#!/usr/bin/env bash
# revisa-secretos.sh - Busca posibles secretos expuestos en una carpeta.
# Imprime "ruta:línea: TIPO" por hallazgo (línea "-" si es el archivo completo),
# NUNCA el valor. Al final, un resumen por tipo.
#
# Uso:    bash scripts/revisa-secretos.sh [carpeta]     (por omisión: .)
# Salida: 0 = sin hallazgos, 1 = hubo hallazgos, 2 = error de uso.
#
# Funciona con bash 3.2+ y grep de GNU o BSD (Linux, macOS, Git Bash).
# Windows: ejecútalo desde Git Bash, no con el bash de WSL. Desde PowerShell:
#   & "C:\Program Files\Git\bin\bash.exe" scripts/revisa-secretos.sh
#   Rutas como C:/Users/... o /c/Users/..., o entre comillas.
#
# Limitaciones conocidas (falsos negativos):
#   - No revisa el historial de git, solo los archivos actuales.
#   - No revisa binarios ni archivos UTF-16 (grep los trata como binarios).
#   - No detecta secretos sin un nombre que los delate (no mide entropía),
#     ni valores partidos en varias líneas (p. ej. <Password><Value> de
#     unattend.xml en líneas separadas).
set -euo pipefail
export LC_ALL=C

if [ "$#" -gt 1 ]; then
  echo "Uso: $0 [carpeta]" >&2
  exit 2
fi

DIR="${1:-.}"
if [ ! -d "$DIR" ]; then
  echo "Error: la carpeta '$DIR' no existe." >&2
  exit 2
fi
# Una carpeta que empieza con "-" se confundiría con una opción de find
case "$DIR" in -*) DIR="./$DIR" ;; esac

# En Windows, si el PATH está mal, "find" puede ser C:\Windows\System32\find.exe
if ! find "$DIR" -maxdepth 0 >/dev/null 2>&1; then
  echo "Error: 'find' no es el de Unix. Ejecuta este script desde Git Bash." >&2
  exit 2
fi

# Este script contiene los patrones; se excluye para no detectarse a sí mismo
YO="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# --- Patrones (grep -E, sin distinguir mayúsculas) ---------------------------
# Valor literal: no vacío, no empieza con $ { ? ( < ni comilla+$ (referencias a
# variables, subcomandos, etiquetas). Así el script tampoco detecta sus propias copias.
LIT='["'"'"']?[^$"'"'"'{?(<[:space:]][^[:space:]]{3,}'
SEP='["'"'"']?[[:space:]]*[:=][[:space:]]*'

RE_LLAVE='-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----|^PuTTY-User-Key-File-'

RE_CONTRASENA="(password|passwd|pwd|secret|clave|contrase(n|..)a)${SEP}${LIT}"
RE_CONTRASENA="$RE_CONTRASENA|ConvertTo-SecureString[^|]*[\"'][^\$\"'][^\"']{3,}[\"'][^|]*-AsPlainText"
RE_CONTRASENA="$RE_CONTRASENA|<[a-z]*password>[[:space:]]*(<value>)?[^<\$[:space:]][^<]{3,}<"
RE_CONTRASENA="$RE_CONTRASENA|net[[:space:]]+use[[:space:]][^|]*/user:[^[:space:]]+[[:space:]]+[^/\$*%[:space:]][^[:space:]]{3,}"

RE_TOKEN="(token|api_?key|access_?key|secret_?key)[a-z0-9_]*${SEP}[\"']?[a-z0-9_.+/=-]{16,}"
RE_TOKEN="$RE_TOKEN|bearer[[:space:]]+[a-z0-9_.+/=-]{16,}"
RE_TOKEN="$RE_TOKEN|AKIA[0-9A-Z]{16}|gh[pousr]_[a-z0-9]{36}|github_pat_[a-z0-9_]{20,}|xox[baprs]-[a-z0-9-]{10,}"
RE_TOKEN="$RE_TOKEN|AIza[0-9a-z_-]{35}|(^|[^a-z0-9])sk-[a-z0-9_-]{20,}"   # Google, OpenAI

RE_CONEXION="[a-z][a-z0-9+.-]*://[^/:@[:space:]\$]+:[^/@[:space:]\$]+@"
RE_CONEXION="$RE_CONEXION|(server|data[[:space:]]+source)[[:space:]]*=.*(password|pwd)[[:space:]]*=[[:space:]]*[^;\$\"'{[:space:]]"

# Valores de plantilla que no son secretos. Solo cuentan justo después de = : o >
# para no descartar una línea real que mencione "ejemplo" en otro lado.
RE_MARCADOR='[=:>][[:space:]]*["'"'"']?(CAMBIAR|changeme|change_me|ejemplo|example|placeholder|x{4,}|\*{3,}|tu_|your_)'

# --- Conteo y reporte ---------------------------------------------------------
N_ENV=0; N_LLAVE=0; N_CONTRASENA=0; N_TOKEN=0; N_CONEXION=0

reporta() { # ruta línea tipo
  printf '%s:%s: %s\n' "$1" "$2" "$3"
  case "$3" in
    ARCHIVO_ENV)     N_ENV=$((N_ENV + 1)) ;;
    LLAVE_PRIVADA)   N_LLAVE=$((N_LLAVE + 1)) ;;
    CONTRASENA)      N_CONTRASENA=$((N_CONTRASENA + 1)) ;;
    TOKEN)           N_TOKEN=$((N_TOKEN + 1)) ;;
    CADENA_CONEXION) N_CONEXION=$((N_CONEXION + 1)) ;;
  esac
}

busca() { # archivo tipo patrón
  # Solo se conserva el número de línea; el contenido nunca se imprime.
  local n
  for n in $(grep -nIiE -e "$3" -- "$1" 2>/dev/null | grep -viE -e "$RE_MARCADOR" | cut -d: -f1 || true); do
    reporta "$1" "$n" "$2"
  done
}

while IFS= read -r -d '' f; do
  if [ "$f" -ef "$YO" ]; then continue; fi
  f="${f#./}"

  case "${f##*/}" in
    .env.example|.env.sample|.env.template) ;;
    .env|.env.*)                 reporta "$f" - ARCHIVO_ENV ;;
    *.pfx|*.p12|*.PFX|*.P12)     reporta "$f" - LLAVE_PRIVADA ;;
  esac

  busca "$f" LLAVE_PRIVADA   "$RE_LLAVE"
  busca "$f" CONTRASENA      "$RE_CONTRASENA"
  busca "$f" TOKEN           "$RE_TOKEN"
  busca "$f" CADENA_CONEXION "$RE_CONEXION"
done < <(find "$DIR" \( -name .git -o -name node_modules \) -prune -o -type f -print0)

TOTAL=$((N_ENV + N_LLAVE + N_CONTRASENA + N_TOKEN + N_CONEXION))
echo "Resumen: ARCHIVO_ENV=$N_ENV LLAVE_PRIVADA=$N_LLAVE CONTRASENA=$N_CONTRASENA TOKEN=$N_TOKEN CADENA_CONEXION=$N_CONEXION (total $TOTAL)"

if [ "$TOTAL" -gt 0 ]; then
  exit 1
fi
exit 0
