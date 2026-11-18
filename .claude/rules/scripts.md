---
paths:
  - "scripts/**/*.sh"
---

# Reglas para scripts de bash

Lo aprendido en la Sesión 1. Los scripts deben correr igual en macOS (bash 3.2, herramientas
BSD), Linux y Git Bash. Referencia de cada script: `docs/scripts.md`.

## Estructura
- Primera línea `#!/usr/bin/env bash`, luego un comentario con qué hace y cómo se usa.
- `set -euo pipefail` y comentarios cortos.
- Valida los argumentos al inicio. Códigos de salida: 0 bien, 1 hallazgos o fallo, 2 uso incorrecto.
- Rutas relativas a la raíz: `RAIZ="$(cd "$(dirname "$0")/.." && pwd)"`.
- Entrecomilla siempre las variables (hay rutas con espacios).

## Portabilidad (bash 3.2 de macOS y grep BSD)
- Sin `declare -A` ni `mapfile`/`readarray`; tampoco `${x,,}` ni `${x^^}`.
- `grep -E`, nunca `grep -P`. Clases POSIX: `[[:space:]]` y `[0-9]`, no `\s`, `\d` ni `\b`.
- En GNU grep (Linux y Git Bash), si el primer filtro es `--exclude`, se incluyen todos los
  archivos que no coinciden con `--include`. Pon `--include` primero.
- Evita `sed -i`: BSD y GNU lo usan distinto. `find -mtime` sí es igual en los dos.
- Con `set -e` y `pipefail`, un `grep` sin coincidencias sale con 1 y mata el script: usa
  `|| true` donde "no encontrar nada" sea normal.
- Con archivos de nombres raros o acentos mal codificados: `LC_ALL=C` y listas con `-print0` o
  `--null`.
- Pruébalos en Git Bash, no en PowerShell ni CMD.

## Secretos
- Las credenciales vienen de variables de entorno; nunca las escribas en el script.
- Valida que existan sin imprimirlas: `: "${DB_HOST:?Falta DB_HOST}"`.
- Un script que busca secretos reporta `ruta:línea:tipo` y descarta el contenido (`cut -d: -f1,2`).
  No imprimas la línea ni "para depurar".
- Al escanear, excluye `.git/` y el propio script (contiene los patrones).

## Revisión
- `bash -n` solo revisa la sintaxis. Un cambio como `-mtime -7` en lugar de `-mtime +7` pasa
  limpio: lee el diff de la lógica.
- Los finales de línea son LF (`.gitattributes`); no los cambies.
- Si cambias un script, actualiza `docs/scripts.md` en el mismo commit.
