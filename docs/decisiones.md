# Decisiones

Registro corto de por qué el repositorio está como está. Cada entrada lleva la fecha del commit
que la respalda. Si tomas una decisión nueva, agrégala al final con el mismo formato.

Estados: **vigente**, **por confirmar** (el repositorio no registra el motivo).

## 1. Los datos son ficticios y los secretos están sembrados a propósito
- **Fecha:** 2026-11-10 (`fc8dc5f`) · **Estado:** vigente
- **Decisión:** servidores, usuarios, tokens, llaves y logs son inventados. El `.env`, el
  `config/.env.produccion`, `llaves/id_practica` y credenciales dentro de `scripts/notifica.sh`
  y `config/app.conf` están versionados para que la práctica de la Sesión 1 tenga qué encontrar.
- **Consecuencia:** `revisa-secretos.sh` siempre sale con código 1 aquí. `.gitignore` lo avisa y
  dice que en un repositorio real `.env*` y `llaves/` irían ignorados.

## 2. Credenciales solo por variables de entorno
- **Fecha:** 2026-11-10 (`df1d2fe`) · **Estado:** vigente
- **Decisión:** `respaldo.sh` lee `DB_HOST`, `DB_USER` y `DB_PASSWORD` del entorno, y nunca de
  un archivo ni del script. Valida que existan sin imprimir su valor.
- **Consecuencia:** `notifica.sh`, con su token escrito dentro, es la excepción y está marcada
  como mala práctica a propósito. `.env.example` es la plantilla de las variables.

## 3. El volcado de la base va a `respaldos/`
- **Fecha:** 2026-11-10 (`f5e1d0b`) · **Estado:** vigente
- **Decisión:** el volcado de `pg_dump` se guarda en `respaldos/`, no dentro de la carpeta
  que se respalda.
- **Consecuencia:** el volcado no termina dentro de la carpeta de origen ni se mezcla con ella.
  `respaldos/` está en `.gitignore`.

## 4. Scripts en bash y grep, portables
- **Fecha:** 2026-11-10 (`5f33165`) · **Estado:** vigente
- **Decisión:** los scripts usan solo bash y herramientas estándar, y deben funcionar en macOS
  (bash 3.2, herramientas BSD), Linux y Git Bash. En Windows se ejecutan en Git Bash.
- **Consecuencia:** las reglas concretas (sin arreglos asociativos, `grep -E`, orden de
  `--include` y `--exclude`, etc.) están en `.claude/rules/scripts.md`. `.gitattributes` fuerza
  finales de línea LF para que los scripts también corran en Git Bash con `core.autocrlf`.

## 5. `revisa-secretos.sh` nunca imprime el valor
- **Fecha:** 2026-11-10 (`5f33165`) · **Estado:** vigente
- **Decisión:** el revisor reporta ruta, línea y tipo, y descarta el contenido de la línea
  (queda solo `ruta:línea`). Un `.env` cuenta como un solo hallazgo de archivo completo.
- **Consecuencia:** imprimir la salida de `grep -n` tal cual filtraría el secreto; es la falla
  más común en este ejercicio. Las plantillas (`.env.example`) no cuentan.

## 6. Permisos de Claude Code del proyecto
- **Fecha:** 2026-11-10 (`5f33165`) y 2026-11-17 (`6407b17`) · **Estado:** vigente, con un
  punto por confirmar
- **Decisión:** `.claude/settings.json` niega la lectura de `.env`, `.env.*`, `llaves/` y
  `~/.ssh/`, y niega `cat .env*` y `rm -rf *`. Pide confirmación para `git push`, `docker`,
  `ssh`, `systemctl` y cualquier script de `scripts/`. Permite `git status`, `git diff`,
  `git log` y ejecutar `revisa-secretos.sh`.
- **Por confirmar:** `6407b17` agregó también un `deny` a `git commit`, de modo que Claude no
  puede hacer commits en este repositorio. El historial no dice el motivo; parece intencional
  para la Sesión 2, pero conviene confirmarlo con el instructor.
- **Consecuencia:** una regla `deny` gana sobre cualquier `allow` o `ask`, venga del archivo
  que venga. Los `deny` de `Read(**/.env.*)` bloquean también `.env.example`, así que en una
  sesión dentro del repositorio Claude no puede leer la plantilla.

## 7. Se trabaja en ramas y en un fork
- **Fecha:** 2026-11-17 (`0df3033`) · **Estado:** vigente
- **Decisión:** cada persona trabaja en su fork y en una rama propia (`s2-<nombre>`, creada
  desde `upstream/s2-inicio`). No se hace commit directo a `main`.
- **Consecuencia:** los cambios llegan al repositorio del curso por pull request. En Windows,
  todo en Git Bash.
- **Nota:** el `CLAUDE.md` personal de cada persona puede pedir lo contrario (todo en `main`).
  En este repositorio manda el `CLAUDE.md` del proyecto.
