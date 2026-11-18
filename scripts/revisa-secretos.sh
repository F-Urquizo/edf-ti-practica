#!/usr/bin/env bash
# revisa-secretos.sh - Busca secretos expuestos en un repositorio.
# Reporta ruta, línea y tipo de cada hallazgo. NUNCA imprime el valor del secreto.
#
# Uso:    ./scripts/revisa-secretos.sh [--json] [carpeta]   (por defecto: la carpeta actual)
#         --json imprime solo un arreglo JSON [{"ruta","linea","tipo"}]; "linea" es null en .env.
# Salida: código 0 si no hay hallazgos, 1 si encuentra algo, 2 si hay error de uso.
#
# Solo usa bash y grep. Compatible con bash 3.2 (macOS), Linux y Git Bash.
set -euo pipefail

DIR="."
JSON=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    *) DIR="$arg" ;;
  esac
done
if [ ! -d "$DIR" ]; then
  echo "Error: la carpeta '$DIR' no existe." >&2
  exit 2
fi
cd "$DIR"

# Carpetas que no se revisan
EXCLUIR_DIRS=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=respaldos)
# Este script contiene los patrones: se excluye a sí mismo
EXCLUIR_SCRIPT=(--exclude=revisa-secretos.sh)
# En el escaneo por línea se omiten los .env: ya se reportan como archivo completo
EXCLUIR_ENV=(--exclude=.env --exclude='.env.*')

# Patrones (expresiones regulares extendidas)
PATRON_ENV_VAR='^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*='
PATRON_LLAVE='-----BEGIN [A-Z ]*PRIVATE KEY-----'
PATRON_TOKEN='(token|api[_-]?key|secret|secreto)[A-Za-z0-9_]*["'\'']?[[:space:]]*[=:][[:space:]]*["'\'']?[A-Za-z0-9_./+=-]{20,}'
PATRON_PASSWORD='(password|passwd|contrasena|pwd)["'\'']?[[:space:]]*[=:][[:space:]]*["'\'']?[A-Za-z0-9!@#%^&*_+.,;~-]{4,}'

# Contadores por tipo (sin arreglos asociativos, por compatibilidad con bash 3.2)
N_ENV=0
N_LLAVE=0
N_TOKEN=0
N_PASSWORD=0
TOTAL=0

# Hallazgos en JSON, acumulados para imprimirlos al final como un solo arreglo
JSON_ITEMS=""

# Imprime un hallazgo: ruta, línea y tipo. Nunca recibe el contenido de la línea.
# Con --json no imprime: acumula el objeto. La línea "-" (archivo .env) pasa a null.
reportar() {
  local ruta="${1#./}" linea="$2" tipo="$3"
  if [ "$JSON" -eq 1 ]; then
    [ "$linea" = "-" ] && linea="null"
    # Escapa \ y " en la ruta. ponytail: no cubre tabuladores ni bytes de control en nombres.
    ruta="$(printf '%s' "$ruta" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    [ -n "$JSON_ITEMS" ] && JSON_ITEMS="$JSON_ITEMS,"$'\n'
    JSON_ITEMS="$JSON_ITEMS  {\"ruta\": \"$ruta\", \"linea\": $linea, \"tipo\": \"$tipo\"}"
  else
    printf '%-32s %-6s %s\n' "$ruta" "$linea" "$tipo"
  fi
  TOTAL=$((TOTAL + 1))
}

# Busca un patrón línea por línea y reporta "ruta linea tipo".
# 'cut -d: -f1,2' descarta el contenido: el valor nunca llega a una variable ni a la pantalla.
buscar_por_linea() {
  local patron="$1" tipo="$2" ruta linea
  while IFS=: read -r ruta linea; do
    reportar "$ruta" "$linea" "$tipo"
    case "$tipo" in
      llave-privada) N_LLAVE=$((N_LLAVE + 1)) ;;
      token-hardcodeado) N_TOKEN=$((N_TOKEN + 1)) ;;
      password-hardcodeado) N_PASSWORD=$((N_PASSWORD + 1)) ;;
    esac
  done < <(grep -rnIiE "${EXCLUIR_DIRS[@]}" "${EXCLUIR_SCRIPT[@]}" "${EXCLUIR_ENV[@]}" -e "$patron" . | cut -d: -f1,2 || true)
}

if [ "$JSON" -eq 0 ]; then
  echo "Revisando secretos en: $DIR"
  echo
  printf '%-32s %-6s %s\n' "ARCHIVO" "LINEA" "TIPO"
  printf '%-32s %-6s %s\n' "-------" "-----" "----"
fi

# 1) Archivos .env versionados (se reporta el archivo completo; las plantillas se omiten)
# Nota: --include debe ir ANTES que cualquier --exclude; en GNU grep (Linux, Git Bash)
# si el primer filtro es --exclude, los archivos que no coinciden se incluyen todos.
while IFS= read -r ruta; do
  reportar "$ruta" "-" "archivo-env"
  N_ENV=$((N_ENV + 1))
done < <(grep -rlIE --include=.env --include='.env.*' \
  --exclude=.env.example --exclude=.env.sample "${EXCLUIR_DIRS[@]}" -e "$PATRON_ENV_VAR" . || true)

# 2) Llaves privadas, 3) tokens y 4) contraseñas escritos en el código
buscar_por_linea "$PATRON_LLAVE" "llave-privada"
buscar_por_linea "$PATRON_TOKEN" "token-hardcodeado"
buscar_por_linea "$PATRON_PASSWORD" "password-hardcodeado"

# Con --json: solo el arreglo; el código de salida sigue siendo 1 si hay hallazgos, 0 si no.
if [ "$JSON" -eq 1 ]; then
  if [ "$TOTAL" -eq 0 ]; then
    echo "[]"
    exit 0
  fi
  printf '[\n%s\n]\n' "$JSON_ITEMS"
  exit 1
fi

# Resumen por tipo
echo
echo "Resumen por tipo:"
printf '  %-22s %d\n' "archivo-env" "$N_ENV"
printf '  %-22s %d\n' "llave-privada" "$N_LLAVE"
printf '  %-22s %d\n' "token-hardcodeado" "$N_TOKEN"
printf '  %-22s %d\n' "password-hardcodeado" "$N_PASSWORD"
echo "Total de hallazgos: $TOTAL"

if [ "$TOTAL" -gt 0 ]; then
  echo "RESULTADO: se encontraron secretos expuestos. No hagas commit hasta resolverlos."
  exit 1
fi
echo "RESULTADO: no se encontraron secretos."
exit 0
