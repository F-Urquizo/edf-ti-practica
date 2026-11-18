# Scripts

Referencia de los scripts de `scripts/`. Todos son bash, corren desde la raíz del repositorio
y están pensados para macOS (bash 3.2), Linux y Git Bash. Las reglas para escribirlos están en
`.claude/rules/scripts.md`.

Las credenciales se leen siempre de variables de entorno (aquí solo se nombran, nunca se
escribe su valor). Si cambias un script, actualiza este archivo en el mismo commit.

| Script | Para qué | Uso | Salida |
|---|---|---|---|
| `respaldo.sh` | Respaldar una carpeta y, si se puede, la base | `./scripts/respaldo.sh <carpeta>` | 0 ok, 2 uso incorrecto |
| `rota-logs.sh` | Rotar y comprimir logs viejos | `./scripts/rota-logs.sh [dias]` | 0 ok |
| `notifica.sh` | Avisar a un webhook | `./scripts/notifica.sh "mensaje"` | 0 ok, 1 falló el envío, 2 uso incorrecto |
| `revisa-secretos.sh` | Buscar secretos expuestos | `./scripts/revisa-secretos.sh [--json] [carpeta]` | 0 limpio, 1 hallazgos, 2 error |

## respaldo.sh

Comprime `<carpeta>` en `respaldos/respaldo-<carpeta>-AAAAMMDD-HHMMSS.tar.gz`.
`respaldos/` está en `.gitignore`.

- **Variables obligatorias:** `DB_HOST`, `DB_USER` y `DB_PASSWORD`. Si falta una, el script se
  detiene antes de hacer nada y el mensaje nombra la variable, no su valor. La plantilla está en
  `.env.example`.
- **Base de datos:** si existe `pg_dump`, también guarda `respaldos/base-AAAAMMDD-HHMMSS.sql`
  (archivo aparte, no va dentro del `.tar.gz`). Si el volcado falla, borra el archivo parcial,
  avisa por stderr y sigue solo con los archivos. Sin `pg_dump`, se omite sin avisar.
- **Dependencias:** `tar`, `gzip`; `pg_dump` es opcional.
- **Errores:** sin exactamente un argumento, o con una carpeta que no existe, sale con 2.

## rota-logs.sh

Renombra cada `.log` de `logs/` a `<nombre>-AAAAMMDD.log` (fecha de la rotación) y lo comprime
con `gzip`. Imprime un renglón por archivo y el total. `[dias]` vale 7 por omisión. Si `logs/` no
existe, avisa y sale con 0.

**Problema conocido:** el `find` usa `-mtime -"$DIAS"`, que selecciona los logs modificados en
los últimos N días, es decir, los que siguen en uso. El comentario del script y el README dicen
"con más de N días", lo que corresponde a `-mtime +"$DIAS"`. Apareció en el commit `76ac01e`
("Prepara la rama de inicio de la Sesión 2"), probablemente a propósito para la práctica.
`bash -n` no lo detecta; solo se ve leyendo el diff. Sigue sin corregirse.

## notifica.sh

Envía con `curl` (`--max-time 10`, método POST) un JSON con el nombre del equipo (`hostname`)
y el mensaje a un webhook ficticio. El dominio termina en `.invalid`, así que nunca resuelve y
el envío siempre falla en la práctica. El JSON se arma a mano: un mensaje con comillas dobles
lo rompe.

**Problema conocido (secreto sembrado):** el token del webhook está escrito dentro del script.
Es una credencial ficticia puesta a propósito para el ejercicio de `revisa-secretos.sh`. En un
script real debería venir de una variable de entorno. No se copia aquí su valor.

## revisa-secretos.sh

Busca secretos expuestos en `[carpeta]` (por omisión, la actual) y reporta ruta, línea y tipo de
cada hallazgo, **nunca el valor**. Solo usa bash y grep.

- **Tipos:** `archivo-env`, `llave-privada`, `token-hardcodeado` y `password-hardcodeado`.
  Los `.env` se reportan como archivo completo; las plantillas (`.env.example`, `.env.sample`)
  no cuentan.
- **No revisa:** `.git/`, `node_modules/`, `respaldos/` ni a sí mismo.
- **Salida:** una tabla, un resumen por tipo y el total. Código 1 si hay algún hallazgo, 2 si
  la carpeta no existe.
- **`--json`:** imprime solo un arreglo JSON de objetos `{"ruta", "linea", "tipo"}`, sin tabla ni
  resumen y nunca con el valor del secreto. `linea` es `null` en los `.env` (se reportan como
  archivo completo). Sin hallazgos imprime `[]`. Los códigos de salida son los mismos que sin la
  opción. Va antes o después de `[carpeta]`. No necesita `jq`. Límite: no escapa tabuladores ni
  bytes de control en nombres de archivo.
- **Resultado esperado en este repositorio:** 5 hallazgos sembrados a propósito:
  `.env`, `config/.env.produccion`, `llaves/id_practica`, `scripts/notifica.sh` y
  `config/app.conf`. Por eso sale con código 1. Cualquier hallazgo fuera de esos cinco es nuevo:
  no hagas commit y avisa (regla de `CLAUDE.md`).
- **Límites:** no revisa el historial de Git, binarios ni secretos con nombre inocente y sin
  formato conocido.
