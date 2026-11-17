#!/usr/bin/env bash
# revisa-secretos.sh - Busca posibles secretos expuestos en una carpeta.
#
# Uso: ./scripts/revisa-secretos.sh [carpeta]    (por omisión, la carpeta actual)
#
# Por cada hallazgo imprime "ruta:línea: tipo", nunca el valor, y al final el
# total por tipo. Los tipos son:
#   archivo-env        un .env con valores (no cuentan .env.example ni otras plantillas)
#   llave-privada      una llave privada (PEM, OpenSSH, PGP o PuTTY)
#   contraseña         una contraseña escrita tal cual en código o configuración
#   token              un token, secreto o llave de API escrito tal cual
#   credencial-en-url  usuario y contraseña dentro de una URL
#
# Código de salida: 0 sin hallazgos, 1 con hallazgos, 2 si hubo un error.
#
# Solo usa bash (3.2 o más nuevo) y grep, así que funciona en macOS, Linux y
# Git Bash. No revisa .git/, node_modules/, .venv/, venv/ ni a sí mismo.

set -u
export LC_ALL=C   # bytes tal cual: grep no se salta archivos con acentos mal codificados

uso() {
  printf '%s\n' \
    'Uso: revisa-secretos.sh [carpeta]   (por omisión, la carpeta actual)' \
    'Busca archivos .env, llaves privadas, contraseñas, tokens y credenciales en URLs.' \
    'Imprime la ruta, la línea y el tipo de cada hallazgo, nunca el valor.' \
    'Sale con 0 si no encontró nada, 1 si encontró algo y 2 si hubo un error.'
}

case "${1:-}" in
  -h | --help) uso; exit 0 ;;
esac
if [ "$#" -gt 1 ]; then
  uso >&2
  exit 2
fi
if ! command -v grep >/dev/null 2>&1; then
  echo 'Error: no encontré grep.' >&2
  exit 2
fi

CARPETA="${1:-.}"
if [ ! -d "$CARPETA" ] || [ ! -r "$CARPETA" ]; then
  echo "Error: '$CARPETA' no es una carpeta que se pueda leer." >&2
  exit 2
fi
if [ "$CARPETA" != / ]; then
  CARPETA="${CARPETA%/}"
fi

YO="${BASH_SOURCE[0]:-$0}"   # este archivo: se salta para que sus patrones no lo marquen
EXCLUIR=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv)
Q="'"

# --- Patrones ---------------------------------------------------------------

MINUSCULAS=abcdefghijklmnopqrstuvwxyz
MAYUSCULAS=ABCDEFGHIJKLMNOPQRSTUVWXYZ

# ci "abc" deja en CI "[aA][bB][cC]": un patrón que no distingue mayúsculas
# (el bash 3.2 de macOS no tiene ${x,,}). Las palabras van en minúsculas.
ci() {
  local s="$1" r="" c antes i=0
  while [ "$i" -lt "${#s}" ]; do
    c="${s:i:1}"
    antes="${MINUSCULAS%%"$c"*}"
    if [ "${#antes}" -lt 26 ]; then
      r="$r[$c${MAYUSCULAS:${#antes}:1}]"
    else
      r="$r$c"
    fi
    i=$((i + 1))
  done
  CI="$r"
}

# alternativas pal1 pal2 ... deja en ALT "pal1|pal2|..." sin distinguir mayúsculas.
alternativas() {
  local p r=""
  for p in "$@"; do
    ci "$p"
    r="${r:+$r|}$CI"
  done
  ALT="$r"
}

# Nombres que delatan un secreto. La palabra cierra el nombre o va seguida de
# _ o -: cuentan DB_PASSWORD y TOKEN_WEBHOOK, no "secretaria" ni "tokens".
alternativas password passwd pwd 'contrase(ñ|n)a'
CLAVES_CONTRASENA="$ALT"
alternativas token secret 'api[_-]?key' 'access[_-]?key' 'private[_-]?key'
CLAVES_TOKEN="$ALT"

# Una asignación: nombre, operador (= : := =>) y valor.
OPERADOR="[\"$Q]?[[:space:]]*(:=|=>|=|:)[[:space:]]*"
VALOR="(\"[^\"]*\"|$Q[^$Q]*$Q|[^[:space:]]*)"
RE_ASIG_CONTRASENA="[A-Za-z0-9_.-]*($CLAVES_CONTRASENA)([_-][A-Za-z0-9_-]*)?$OPERADOR$VALOR"
RE_ASIG_TOKEN="[A-Za-z0-9_.-]*($CLAVES_TOKEN)([_-][A-Za-z0-9_-]*)?$OPERADOR$VALOR"

# Nombres que describen el secreto en vez de contenerlo: TOKEN_URL, PASSWORD_FILE...
alternativas url uri endpoint file path dir name type header length len size count ttl \
  'expires([_-](in|at))?' expiry timeout field
RE_SUFIJO_DATO="[_-]($ALT)\$"

# Valores de relleno que no son secretos.
alternativas cambiar_en_el_servidor changeme change_me change-me cambiar cambiame \
  password passwd pass pwd 'contrase(ñ|n)a' clave secret secreto token bearer basic \
  example ejemplo dummy test prueba null none nil undefined true false todo \
  redacted placeholder 'your[_-].*' 'tu[_-].*'
RE_RELLENO="^($ALT|[xX]+|[*]+|[.]+)\$"

ci bearer
RE_BEARER="$CI[[:space:]]+([^[:space:]\"$Q\`]+)"
RE_TOKEN68='^[A-Za-z0-9._~+/=-]{8,}$'

ci convertto-securestring; P_SECURE="$CI"
ci -string; P_STRING="$CI"
ci -asplaintext; P_PLANO="$CI"
RE_SECURESTRING="$P_SECURE[[:space:]]+($P_STRING[[:space:]]+)?(\"[^\"]*\"|$Q[^$Q]*$Q)[[:space:]]+$P_PLANO"

RE_URL_CREDENCIAL="[A-Za-z][A-Za-z0-9+.-]*://([^/[:space:]:@\"$Q]+):([^/[:space:]@\"$Q]*)@"
RE_URL='^[A-Za-z][A-Za-z0-9+.-]*://'
RE_LLAVE='-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----'
RE_PUTTY='^PuTTY-User-Key-File-[0-9]+:'
RE_EXPRESION='^[A-Za-z_][A-Za-z0-9_]*[.][A-Za-z_]|[(]'
CORTE="[,;)\"$Q&]"

# Formatos conocidos, aunque el nombre de la variable no los delate.
FORMATOS=(
  'AKIA[0-9A-Z]{16}'
  'gh[pousr]_[A-Za-z0-9]{36}'
  'github_pat_[A-Za-z0-9_]{22,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'AIza[0-9A-Za-z_-]{35}'
  'sk_live_[0-9A-Za-z]{16,}'
  'eyJ[A-Za-z0-9_-]{10,}[.]eyJ[A-Za-z0-9_-]{10,}[.][A-Za-z0-9_-]+'
)

# Filtro grueso para grep (sin distinguir mayúsculas); bash decide después.
CANDIDATAS='pass|pwd|contrase|token|secret|api[_-]?key|access[_-]?key|private[_-]?key|private key|putty-user-key-file|bearer|://[^/[:space:]]*:[^/[:space:]]*@|akia[0-9a-z]{16}|gh[pousr]_|github_pat_|xox[baprs]-|aiza|sk_live_|eyj[a-z0-9_-]{10,}[.]|convertto-securestring'

RE_ENV_GREP='^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*='
RE_ENV='^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*=(.*)$'

# --- Reglas -----------------------------------------------------------------

N_ENV=0; N_LLAVE=0; N_CONTRASENA=0; N_TOKEN=0; N_URL=0
TIPO=""

reportar() {   # $1 ruta, $2 línea, $3 tipo. Nunca recibe el valor.
  printf '%s:%s: %s\n' "${1#./}" "$2" "$3"
  case "$3" in
    archivo-env) N_ENV=$((N_ENV + 1)) ;;
    llave-privada) N_LLAVE=$((N_LLAVE + 1)) ;;
    contraseña) N_CONTRASENA=$((N_CONTRASENA + 1)) ;;
    token) N_TOKEN=$((N_TOKEN + 1)) ;;
    credencial-en-url) N_URL=$((N_URL + 1)) ;;
  esac
}

es_codigo() {   # $1 extensión: en código, un valor sin comillas es una variable
  case "$1" in
    py | js | mjs | cjs | ts | tsx | jsx | java | kt | go | rb | php | cs | c | cc | cpp | \
      h | hpp | swift | rs | scala | ps1 | psm1 | vb | lua | pl | dart) return 0 ;;
  esac
  return 1
}

valor_literal() {   # ¿$1 parece un secreto escrito tal cual?
  local v="$1"
  [ "${#v}" -ge 4 ] || return 1
  case "$v" in
    '$'* | '%'* | '<'* | '{'* | '['* | '('* | '`'* | '/'* | './'* | '~/'*) return 1 ;;
  esac
  [[ $v =~ $RE_URL ]] && return 1
  [[ $v =~ $RE_RELLENO ]] && return 1
  return 0
}

# ¿El valor de una asignación es un secreto? $1 texto antes del nombre,
# $2 operador, $3 sufijo del nombre, $4 valor, $5 resto de la línea, $6 extensión.
valor_es_secreto() {
  local antes="$1" op="$2" sufijo="$3" v="$4" resto="$5" ext="$6"
  local comillas=0 dentro=0 q siguiente
  case "$antes" in
    *'${' | *'${!' | *'${#' | *'%') return 1 ;;   # ${VAR...} o %VAR%: se lee la variable
    *'$') [ "$op" = '=' ] || return 1 ;;          # $var = "x" asigna en PowerShell, PHP o Perl
  esac
  [[ $sufijo =~ $RE_SUFIJO_DATO ]] && return 1
  # Entre comillas, el valor llega hasta la comilla que cierra (puede seguir un ; o una ,).
  case "$v" in
    '='* | '~'*) return 1 ;;                      # == o =~: es una comparación
    \"*) comillas=1; v="${v#\"}"; v="${v%%\"*}" ;;
    \'*) comillas=1; v="${v#\'}"; v="${v%%\'*}" ;;
    *) v="${v%%$CORTE*}" ;;                       # sin lo que cierra la instrucción
  esac
  if [ "$comillas" -eq 0 ]; then
    # ¿Va dentro de una cadena, como en una cadena de conexión? Comillas sin cerrar antes.
    q="${antes//[^\"]/}"
    [ $(( ${#q} % 2 )) -eq 1 ] && dentro=1
    q="${antes//[^$Q]/}"
    [ $(( ${#q} % 2 )) -eq 1 ] && dentro=1
    if [ "$dentro" -eq 0 ] && es_codigo "$ext"; then return 1; fi
    [[ $v =~ $RE_EXPRESION ]] && return 1
    # Una nota en texto: dos puntos y más palabras después.
    if [ "$op" = ':' ]; then
      siguiente="${resto#"${resto%%[![:space:]]*}"}"
      case "$siguiente" in
        '' | '#'* | '//'* | \"* | \'*) ;;
        *) return 1 ;;
      esac
    fi
  fi
  valor_literal "$v"
}

asignacion_literal() {   # $1 patrón, $2 línea, $3 extensión
  local re="$1" l="$2" ext="$3" m n antes op sufijo v
  while [[ $l =~ $re ]]; do
    m="${BASH_REMATCH[0]}"
    n=${#BASH_REMATCH[@]}
    sufijo="${BASH_REMATCH[n-3]}"
    op="${BASH_REMATCH[n-2]}"
    v="${BASH_REMATCH[n-1]}"
    antes="${l%%"$m"*}"
    l="${l#*"$m"}"
    valor_es_secreto "$antes" "$op" "$sufijo" "$v" "$l" "$ext" && return 0
  done
  return 1
}

url_con_credencial() {
  local l="$1" m clave
  while [[ $l =~ $RE_URL_CREDENCIAL ]]; do
    m="${BASH_REMATCH[0]}"
    clave="${BASH_REMATCH[2]}"
    l="${l#*"$m"}"
    valor_literal "$clave" && return 0
  done
  return 1
}

bearer_literal() {
  local l="$1" m v
  while [[ $l =~ $RE_BEARER ]]; do
    m="${BASH_REMATCH[0]}"
    v="${BASH_REMATCH[1]}"
    l="${l#*"$m"}"
    [[ $v =~ $RE_TOKEN68 ]] && valor_literal "$v" && return 0
  done
  return 1
}

securestring_literal() {   # ConvertTo-SecureString con texto fijo y -AsPlainText
  local v
  [[ $1 =~ $RE_SECURESTRING ]] || return 1
  v="${BASH_REMATCH[2]}"
  valor_literal "${v:1:${#v}-2}"
}

formato_conocido() {
  local re
  for re in "${FORMATOS[@]}"; do
    if [[ $1 =~ $re ]]; then
      case "${BASH_REMATCH[0]}" in
        *EXAMPLE* | *example*) continue ;;   # claves de ejemplo de la documentación
      esac
      return 0
    fi
  done
  return 1
}

clasificar() {   # $1 línea, $2 extensión. Deja el tipo en TIPO.
  local l="$1" ext="$2"
  if [[ $l =~ $RE_LLAVE ]] || [[ $l =~ $RE_PUTTY ]]; then
    TIPO=llave-privada; return 0
  fi
  if url_con_credencial "$l"; then
    TIPO=credencial-en-url; return 0
  fi
  if asignacion_literal "$RE_ASIG_CONTRASENA" "$l" "$ext" || securestring_literal "$l"; then
    TIPO=contraseña; return 0
  fi
  if asignacion_literal "$RE_ASIG_TOKEN" "$l" "$ext" || bearer_literal "$l" || formato_conocido "$l"; then
    TIPO=token; return 0
  fi
  return 1
}

valor_env() {   # ¿El valor de una línea VAR=valor de un .env es de verdad?
  local v="$1"
  v="${v%%[[:space:]]#*}"            # sin comentario al final
  v="${v#"${v%%[![:space:]]*}"}"     # sin espacios al inicio
  v="${v%"${v##*[![:space:]]}"}"     # ni al final
  case "$v" in
    \"*\" | \'*\') v="${v:1:${#v}-2}" ;;
  esac
  [ -n "$v" ] || return 1
  case "$v" in '$'*) return 1 ;; esac
  [[ $v =~ $RE_RELLENO ]] && return 1
  return 0
}

revisar_env() {   # $1 archivo .env: un hallazgo en la primera línea con valor
  local f="$1" linea num
  while IFS= read -r linea; do
    num="${linea%%:*}"
    linea="${linea#*:}"
    linea="${linea%$'\r'}"
    [[ $linea =~ $RE_ENV ]] || continue
    if valor_env "${BASH_REMATCH[2]}"; then
      reportar "$f" "$num" archivo-env
      return
    fi
  done < <(grep -n -E -e "$RE_ENV_GREP" -- "$f" 2>/dev/null)
}

# --- Revisión ---------------------------------------------------------------

# 1) Archivos .env, por su nombre. Los nombres llegan separados por NUL.
while IFS= read -r -d '' f; do
  [ "$f" -ef "$YO" ] && continue
  case "${f##*/}" in
    *.example | *.sample | *.template | *.dist) ;;
    .env | .env.* | *.env) revisar_env "$f" ;;
  esac
done < <(grep -r -l -I --null "${EXCLUIR[@]}" -e '^' -- "$CARPETA" 2>/dev/null)

# 2) Líneas candidatas. El contenido solo vive en variables: nunca se imprime.
anterior=""
saltar=0
ext=""
while IFS= read -r -d '' f && IFS= read -r resto; do
  if [ "$f" != "$anterior" ]; then
    anterior="$f"
    saltar=0
    [ "$f" -ef "$YO" ] && saltar=1
    nombre="${f##*/}"
    case "$nombre" in
      *.*) ext="${nombre##*.}" ;;
      *) ext="" ;;
    esac
  fi
  [ "$saltar" -eq 1 ] && continue
  num="${resto%%:*}"
  linea="${resto#*:}"
  linea="${linea%$'\r'}"
  if clasificar "$linea" "$ext"; then
    reportar "$f" "$num" "$TIPO"
  fi
done < <(grep -r -n -I -i -E --null "${EXCLUIR[@]}" -e "$CANDIDATAS" -- "$CARPETA" 2>/dev/null)

TOTAL=$((N_ENV + N_LLAVE + N_CONTRASENA + N_TOKEN + N_URL))
echo
echo 'Resumen:'
printf '  %4d  %s\n' \
  "$N_ENV" archivo-env \
  "$N_LLAVE" llave-privada \
  "$N_CONTRASENA" contraseña \
  "$N_TOKEN" token \
  "$N_URL" credencial-en-url \
  "$TOTAL" total
[ "$TOTAL" -eq 0 ] || exit 1
exit 0
