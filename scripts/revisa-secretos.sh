#!/usr/bin/env bash
# revisa-secretos.sh - Busca posibles secretos expuestos en una carpeta.
# Uso: ./scripts/revisa-secretos.sh [carpeta]   (por omisión: la carpeta actual)
# Imprime "ruta:línea: tipo" por hallazgo. NUNCA imprime el valor encontrado.
# Códigos de salida: 0 sin hallazgos, 1 con hallazgos, 2 uso incorrecto.
# Solo bash y grep (ERE POSIX, sin -P ni GNU-isms) para que corra en macOS y Linux.
# Límites: revisa el árbol de trabajo, no el historial de Git; no mira binarios;
# no detecta secretos partidos en varias líneas ni codificados.
set -u
export LC_ALL=C

DIR="${1:-.}"
if [ "$#" -gt 1 ] || [ ! -d "$DIR" ]; then
  echo "Uso: $0 [carpeta]" >&2
  exit 2
fi
case "$DIR" in -*) DIR="./$DIR" ;; esac

# Patrones (ERE). Los valores asignados deben ser literales: si empiezan con $ no cuentan.
LLAVE='BEGIN [A-Z ]*PRIVATE KEY'
TOKEN_PREF='AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}|Bearer [A-Za-z0-9._-]{20,}'
TOKEN_ASIG="(token|secret|api_?key)[A-Za-z0-9_]*[\"']?[[:space:]]*[=:][[:space:]]*[\"']?[A-Za-z0-9_./+=-]{16,}"
PASS_ASIG="(password|passwd|pwd|contraseña|clave)[A-Za-z0-9_]*[\"']?[[:space:]]*[=:][[:space:]]*[\"']?[^[:space:]\"'\$<{(][^[:space:]\"']{3,}"
# Valores de relleno que no son secretos (se compara contra lo que sigue al = o :)
RELLENO="[=:][[:space:]]*[\"']?(CAMBIAR|changeme|change_me|ejemplo|example|placeholder|x{4,}|\*{3,}|tu_|your_)"

N_ENV=0; N_LLAVE=0; N_TOKEN=0; N_PASS=0

hallazgo() { # $1=ruta $2=línea $3=tipo
  echo "$1:$2: $3"
  case "$3" in
    archivo-env)   N_ENV=$((N_ENV + 1)) ;;
    llave-privada) N_LLAVE=$((N_LLAVE + 1)) ;;
    token)         N_TOKEN=$((N_TOKEN + 1)) ;;
    contrasena)    N_PASS=$((N_PASS + 1)) ;;
  esac
}

en_lista() { printf '%s\n' "$2" | grep -qx "$1"; } # ¿el número $1 está en la lista $2?

while IFS= read -r -d '' f; do
  ruta="${f#./}"
  base="${f##*/}"

  # Archivos .env: el archivo completo es el hallazgo (no se escanea por dentro).
  case "$base" in
    *.example|*.sample|*.template) ;;
    .env|.env.*|*.env) hallazgo "$ruta" - archivo-env; continue ;;
  esac

  # Solo se guardan números de línea (cut): el contenido nunca sale de estas tuberías.
  llaves=$(grep -nIE "$LLAVE" "$f" | cut -d: -f1)
  tokens=$( { grep -nIE "$TOKEN_PREF" "$f"
              grep -nIiE "$TOKEN_ASIG" "$f" | grep -viE "$RELLENO" | grep -vF '${'
            } | cut -d: -f1 | sort -nu )
  claves=$(grep -nIiE "$PASS_ASIG" "$f" | grep -viE "$RELLENO" | grep -vF '${' | cut -d: -f1)

  for n in $llaves; do hallazgo "$ruta" "$n" llave-privada; done
  for n in $tokens; do
    en_lista "$n" "$llaves" || hallazgo "$ruta" "$n" token
  done
  for n in $claves; do # una línea se reporta una sola vez: llave > token > contraseña
    en_lista "$n" "$llaves" && continue
    en_lista "$n" "$tokens" && continue
    hallazgo "$ruta" "$n" contrasena
  done
done < <(find "$DIR" \( -name .git -o -name node_modules \) -prune -o -type f -print0)

TOTAL=$((N_ENV + N_LLAVE + N_TOKEN + N_PASS))
echo
echo "Resumen (los valores nunca se imprimen):"
printf '  %-15s %d\n' archivo-env "$N_ENV" llave-privada "$N_LLAVE" token "$N_TOKEN" contrasena "$N_PASS"
echo "Total: $TOTAL"

[ "$TOTAL" -eq 0 ]
