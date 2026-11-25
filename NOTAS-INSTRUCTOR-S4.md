# Notas para el instructor — Sesión 4

Esta rama (`solucion-s4`) es solo para el instructor. Los alumnos parten de `upstream/s4-inicio`,
que es `solucion-s3` sin `NOTAS-INSTRUCTOR-S3.md` y con la sección "Sesión 4" del README.

> Como en las sesiones anteriores, aquí no se escriben valores de secretos.

Ramas:
- `s4-inicio` = `solucion-s3` − `NOTAS-INSTRUCTOR-S3.md` + sección "Sesión 4" del README. Nada más:
  el MCP, las skills, el subagente y el plugin los construyen los alumnos.
- `solucion-s4` = `s4-inicio` + una pieza por commit: `herramientas/mcp-inventario/`, `.mcp.json`,
  la skill `reporte-incidente`, el subagente `auditor`, la skill `auditoria-diaria`, el plugin
  `edf-ti` con su `marketplace.json`, y estas notas.

Flujo de los alumnos (README, sección "Sesión 4"):
```bash
git fetch upstream s4-inicio
git checkout -b s4-<nombre> upstream/s4-inicio
git push -u origin s4-<nombre>
```
Si `upstream` no existe: `git remote add upstream https://github.com/F-Urquizo/edf-ti-practica.git`.
Docker solo hace falta para el Avanzado del Laboratorio B (respaldos por el MCP de la Sesión 3).

Versiones con las que se probó todo (24 nov 2026): Claude Code 2.1.332, Node 22.20.0, npm 10.9.3,
`@modelcontextprotocol/sdk` 1.32.2, `zod` 4.6.7, `@toolbox-sdk/server` 1.16.0, Docker 28.0.4,
shellcheck 0.10.0.

## 1. Qué hay en la solución

### `herramientas/mcp-inventario/` (Laboratorio A, Base)
- `index.js`: servidor MCP por stdio, de solo lectura, sobre `docs/inventario-servidores.csv`.
  La ruta del CSV sale de la ubicación del archivo (funciona desde cualquier carpeta); se puede
  cambiar con `INVENTARIO_CSV`. Lee el CSV en cada llamada. Mensajes solo a stderr.
- Herramientas, las dos con `readOnlyHint: true`:
  - `buscar_servidor(texto)`: texto libre en todas las columnas, parcial, sin mayúsculas ni acentos.
  - `servidores_por(campo, valor?)`: `campo` es un enum de las 5 columnas. Con `valor`, filtra
    (parcial). **Sin `valor`, devuelve el conteo por cada valor de la columna**: así la pregunta
    del paso 3 se contesta en una sola llamada.
- `prueba.js` (`npm test`): arranca el servidor con el cliente del SDK, lista las herramientas y
  llama a cada una (9 casos).
- `package.json` con versiones exactas; `.gitignore` local con `node_modules/`.
- En un clon nuevo hay que correr `npm ci` (o `npm install`) en `herramientas/mcp-inventario/`
  antes de registrar el servidor.

### `.mcp.json`
Creado con el comando de la lámina, tal cual:
```bash
claude mcp add inventario-csv --scope project -- node herramientas/mcp-inventario/index.js
```
Guarda `"command": "node"` y la ruta **relativa**: Claude Code debe abrirse desde la raíz del repo.

### `.claude/skills/reporte-incidente/` (Laboratorio A, Avanzado)
`SKILL.md` + `plantilla.md` (resumen, impacto, línea del tiempo, causa raíz, acciones y
responsables, pendientes de evidencia). Guarda en `reportes/incidente-AAAA-MM-DD.md` con la fecha
**del incidente**, no la de hoy.

### `.claude/agents/auditor.md` (Laboratorio B)
Idéntico a la lámina 10 (`tools: Read, Grep, Glob, Bash`, `model: haiku`).

### `.claude/skills/auditoria-diaria/` (Laboratorio B, Prompt 4)
Delega al `auditor`, escribe `reportes/auditoria-AAAA-MM-DD.md`; primera línea `OK` o
`N hallazgos`. Toma la fecha del contexto (no corre `date`).

### `plugins/edf-ti/` + `.claude-plugin/marketplace.json` (Laboratorio B, Avanzado)
Como en la lámina 09: la skill `reporte-incidente` y el subagente `auditor` (copias, no enlaces,
para que funcione en Windows). `claude plugin validate .` pasa.

## 2. Mensajes esperados (Claude Code 2.1.332)

**Registro y aprobación del MCP**
- `claude mcp add ...`: `Added stdio MCP server inventario-csv with command: node herramientas/mcp-inventario/index.js to project config`
  y `File modified: <ruta>/.mcp.json` (dice "modified" aunque lo cree).
- `claude mcp list` antes de abrir `claude`:
  `inventario-csv: node herramientas/mcp-inventario/index.js - ⏸ Pending approval (run `claude` to approve)`.
- En una carpeta nueva, el diálogo de confianza ya avisa: `Trusting this folder loads .claude/settings.json and .mcp.json here or above (MCP servers).`
- Después: `New MCP server found in this project: inventario-csv`, con 3 opciones. **La opción
  marcada por defecto es `Continue without using this MCP server`**: quien da Enter sin leer se
  queda sin el MCP. Hay que bajar a `Use this MCP server`.
- `/mcp`: bajo `Project MCPs (<ruta>/.mcp.json)` aparece `✔ inventario-csv   2 tools`.
  Enter → `View tools` → `buscar_servidor  read-only` y `servidores_por  read-only`.
  En el detalle: `Full name:  mcp__inventario-csv__buscar_servidor`. **El guion sobrevive**:
  las reglas son `mcp__inventario-csv__buscar_servidor`, `mcp__inventario-csv` (todo el servidor)
  o `mcp__inventario-csv__*`.
- `mcp__inventario` (sin `-csv`) **no** cubre a `inventario-csv`: el nombre del servidor se compara completo.
- Si el `.mcp.json` apunta a un archivo que no existe (por ejemplo `index.js` cuando Claude creó
  `servidor.js`): `inventario-csv: ... - ✘ Failed to connect — CONNECTION_CLOSED: Connection closed`.

**Permisos con `claude -p`**
- Herramienta MCP sin permiso: `Claude requested permissions to use mcp__inventario-csv__servidores_por, but you haven't granted it yet.`
  Claude entonces lee el CSV con `Read` y contesta igual: **la respuesta correcta no prueba que
  usó el MCP**; hay que ver la línea `Called inventario-csv` (o `mcp__...` en la salida).
- Comando compuesto: `This Bash command contains multiple operations. The following part requires approval: echo "EXIT=$?"`.
  El auditor (haiku) lo intenta casi siempre (`./scripts/revisa-secretos.sh --json; echo "EXIT=$?"`),
  lo niegan y lo repite solo. No rompe la auditoría.
- `ask` gana a `--allowedTools`: con `--allowedTools "Bash(docker *)"`, `docker ps` da
  `Claude requested permissions to use Bash, but you haven't granted it yet.`
- `deny` gana a `--allowedTools`: `Permission to use Bash with command cat .env has been denied.` y,
  para `Read`, `File is in a directory that is denied by your permission settings.`
- Escribir dentro de `.claude/` **siempre pide aprobación**, aun con `--permission-mode acceptEdits`
  y aun con `--allowedTools "Write(.claude/**)"`: `Claude requested permissions to write to <ruta>/.claude/skills/auditoria-diaria/SKILL.md, but you haven't granted it yet.`
  Las skills y el subagente se crean en la sesión interactiva, aprobando.
- No piden aprobación: `Skill`, `Agent` (el subagente), `Read`/`Grep`/`Glob` dentro del repo y
  comandos de solo lectura como `git status`, `git ls-files` y `date`.

**Plugin**
- `claude plugin marketplace add F-Urquizo/edf-ti-practica` (sin rama): `✘ Failed to add marketplace: Marketplace file not found at …/.claude-plugin/marketplace.json`.
  Lee la rama por defecto (`main`), que no tiene el marketplace.
- Con rama: `claude plugin marketplace add F-Urquizo/edf-ti-practica#solucion-s4` →
  `✔ Successfully added marketplace: edf-ti-practica (declared in user settings)`.
- `claude plugin install edf-ti@edf-ti-practica` → `✔ Successfully installed plugin: edf-ti@edf-ti-practica (scope: user)`.
  **El alcance por defecto es `user`** (todas las carpetas del alumno). `--scope project` lo deja en
  `.claude/settings.json` del repo.
- Con el plugin cargado, los nombres llevan prefijo: skill y comando `/edf-ti:reporte-incidente`,
  subagente `edf-ti:auditor`. En este repo convive con la skill del proyecto (`/reporte-incidente`).

**cron (probado con un entorno como el de cron: `env -i`, `PATH=/usr/bin:/bin`, `/bin/sh`)**
- Sin `reportes/` (clon nuevo; la carpeta está en `.gitignore`): `/bin/sh: reportes/cron.log: No such file or directory`.
  La redirección falla antes de arrancar `claude`.
- Con `reportes/`: `/bin/sh: claude: command not found` (salida 127). El instalador deja `claude`
  en `~/.local/bin`, que no está en el PATH de cron.
- Los MCP tampoco arrancan si `node`/`npx` no están en el PATH (nvm los deja en `~/.nvm/...`):
  `✘ Failed to connect — ENOENT: Executable not found in $PATH: "npx"`.
- El MCP `inventario` de la Sesión 3 además necesita `LECTOR_PASSWORD`, que cron no tiene:
  `✘ Failed to connect — CONNECTION_CLOSED: Connection closed`.

## 3. Salida esperada por laboratorio

### Laboratorio A, Base: el MCP
- Prompt 2 en modo plan: Claude revisa los encabezados (`nombre,rol,sistema_operativo,entorno,responsable`,
  10 filas), propone `package.json`, el servidor, un `prueba.js` con el cliente del SDK y una
  entrada de `node_modules/` en `.gitignore`. En manual se aprueban unas 10 acciones (escrituras,
  `npm install`, `node prueba.js`).
- **Con el Prompt 2 tal como está en la lámina v1**, Claude (Opus 5.5) llamó al archivo
  `servidor.js` y se registró solo como `inventario` (`claude mcp add --scope project inventario ...`).
  Con eso, el comando de la lámina agrega un segundo servidor que no conecta (ver §2), y el nombre
  `inventario` choca con el MCP de Postgres de la Sesión 3. Con el texto corregido
  ("En herramientas/mcp-inventario/index.js ..." y "No lo registres: eso lo hago yo con claude mcp add")
  creó `index.js`, no se registró, y el comando de la lámina conectó a la primera.
- «¿Cuántos servidores hay por sistema operativo?» → Claude elige
  `mcp__inventario-csv__servidores_por` con `{"campo":"sistema_operativo"}`. Resultado:

  | Sistema operativo | Servidores |
  |---|---|
  | RHEL 9.2 | 3 (srv-app-prod-01, srv-app-prod-02, db-prod-01) |
  | Debian 12 | 2 (srv-web-qa-01, srv-monitoreo-01) |
  | Ubuntu 22.04 LTS | 2 (srv-app-dev-01, db-dev-01) |
  | RHEL 8.8 | 1 (srv-batch-prod-01) |
  | Ubuntu 20.04 LTS | 1 (srv-respaldos-01) |
  | Windows Server 2022 | 1 (srv-ad-01) |

  Por familia: 4 RHEL, 3 Ubuntu, 2 Debian, 1 Windows. Si el MCP del alumno exige `valor`, Claude
  llama a `servidores_por` una vez por sistema operativo (7 llamadas): buen tema para el cierre
  sobre diseñar herramientas por tarea (lámina 06, paso 2).
- Otras preguntas útiles: «¿qué servidores son de producción?» (7), «¿de qué es responsable
  Infraestructura?» (3: srv-respaldos-01, srv-monitoreo-01, srv-ad-01).

### Laboratorio A, Avanzado: la skill del reporte
- Prompt 3 deja `reportes/incidente-2026-11-22.md` o `-21.md` (según qué fecha tome como inicio:
  el ataque empieza el 21 a las 23:37 y el acceso es el 22 a las 05:13). 90 a 130 líneas, unos 13 `[pendiente]`
  (severidad, responsables, fechas, qué hizo el atacante dentro de la sesión).
- Prompt 1 muestra el `SKILL.md` y pregunta antes de guardar, como pide el prompt.
- `/clear` + «hazme el postmortem de anoche» → `Skill(reporte-incidente)` → `Loaded skill` → escribe
  el reporte. Probado con la skill de la solución y con la que escribió Claude en el clon del alumno.

### Laboratorio B, Base: subagente, skill y `claude -p`
- Prompt 4 tal cual: la skill que escribe Claude suele tomar la fecha con `date +%F`. No hace falta
  agregarlo a `--allowedTools`: es de solo lectura y no pide aprobación.
- El comando de la lámina 12, tal cual, **funciona**: el `--allowedTools` separado por comas con
  `Bash(... *)` se interpreta bien, y `Bash(./scripts/revisa-secretos.sh *)` también cubre el
  script sin argumentos. Secuencia: `Skill` → `Agent` (auditor) → `Bash` del escáner y
  `git status`, `Read` de `.claude/settings.json` → `Write` del reporte. Unos 60 s y unos
  0.35 USD por corrida (sesión en Opus, auditor en haiku).
- Primera línea del reporte: **no es fija**. `6 hallazgos` es lo más común: los 5 sembrados más una
  observación de haiku sobre `settings.json` (por ejemplo que `Bash(cat .env*)` no cubre
  `config/.env.produccion`, o que `grep`/`head` sobre `.env` no están negados). Con cambios sin
  commit suben (8, 9, 11). Si un alumno ve `OK`, revisen juntos: el escáner siempre da 5.
- `Write` crea `reportes/` si no existe.

### Laboratorio B, Avanzado
**Respaldos por el MCP de la Sesión 3.** Requisitos: `docker compose up -d` (solo `db`), el MCP
`inventario` registrado con el comando del Laboratorio 3 de la Sesión 3 y `LECTOR_PASSWORD`
exportada antes de abrir `claude`.
- Agregar `mcp__inventario__execute_sql` a `--allowedTools` **no basta**: el `auditor` solo tiene las
  herramientas de su línea `tools`. Sin cambiarla, no consulta la base y el reporte no trae respaldos.
  Claude mismo lo propone si se le pide: «agrega `mcp__inventario__execute_sql` a `tools` del auditor».
- Versión probada del auditor (además del texto de la lámina):
  ```
  tools: Read, Grep, Glob, Bash, mcp__inventario__execute_sql
  ...
  Con mcp__inventario__execute_sql, lista los servidores sin respaldo exitoso en 7 días; cada uno es un hallazgo.
  ```
  Resultado esperado: `srv-ad-01`, `srv-monitoreo-01` (último exitoso hace 10 a 13 días con la base
  creada el 23 nov) y `srv-web-qa-01` (nunca). Haiku a veces adivina una columna
  (`ERROR: column r.servidor_id does not exist (SQLSTATE 42703)`), consulta el esquema y corrige.
- **Ojo con «máximo 10 líneas»** del auditor: 5 secretos + reglas + cambios sin commit + 3 servidores
  pasan de 10, y en una de dos corridas haiku dejó fuera los respaldos. Súbanlo a 15 para este Avanzado.

**Programarla con cron.** Línea que sí funciona (probada con el entorno de cron):
```
PATH=/Users/<usuario>/.nvm/versions/node/v22.20.0/bin:/Users/<usuario>/.local/bin:/usr/local/bin:/usr/bin:/bin
0 7 * * 1-5 cd $HOME/edf-ti-practica && mkdir -p reportes && claude -p "Usa la skill auditoria-diaria" --allowedTools "Read,Grep,Glob,Write,Bash(./scripts/revisa-secretos.sh *),Bash(git status *)" >> reportes/cron.log 2>&1
```
- La línea `PATH=` va arriba, sola, en el crontab. Cada quien la arma con `dirname $(which node)` y
  `dirname $(which claude)`; cron no expande `$HOME` en esa línea en todas las versiones, así que va
  la ruta completa.
- Para la versión con respaldos, después de `cd ...`: `set -a && . ./.env && set +a && ` (carga
  `LECTOR_PASSWORD`) y `mcp__inventario__execute_sql` en `--allowedTools`. En un repo real la
  contraseña no vive en `.env` versionado.
- Para probar "dentro de dos minutos": `date` y poner minuto y hora exactos, por ejemplo `47 7 * * *`.

**Plugin desde el fork.**
```
/plugin marketplace add <usuario-github>/edf-ti-practica#s4-<nombre>
/plugin install edf-ti@edf-ti-practica
```
Se instala para el usuario (todas sus carpetas). Para quitarlo al final:
`/plugin uninstall edf-ti@edf-ti-practica` y `/plugin marketplace remove edf-ti-practica`.

## 4. Fallas comunes

**Laboratorio A**
- Enter en el diálogo del MCP: queda `Continue without using this MCP server`. Arreglo: `/mcp` →
  `inventario-csv` → habilitarlo, o salir y volver a abrir `claude`.
- Abrir `claude` desde `herramientas/mcp-inventario/`: la ruta relativa del `.mcp.json` no existe
  ahí. Siempre desde la raíz del repo.
- No correr `npm install` en la carpeta del MCP (por ejemplo, al cambiar de computadora o al clonar
  `solucion-s4`): `Failed to connect`.
- Registrar sin reiniciar: el MCP no aparece hasta salir (`/exit`) y volver a abrir `claude`.
- Responder la pregunta sin el MCP: si negaron el permiso, Claude lee el CSV y acierta igual.
- `node_modules/` en el commit: antes del `git add herramientas/`, `git status` no debe mostrarlo.
  En las pruebas Claude agregó `node_modules/` a un `.gitignore` las dos veces, pero no es seguro.

**Laboratorio B**
- Quitar la regla `ask` de `docker` «para que corra sola». No: los respaldos van por el MCP de solo lectura.
- Esperar que `tools` limite los comandos de Bash: no lo hace. El auditor corrió `whoami` y `ls scripts`
  sin problema; lo que limita es `--allowedTools` y `settings.json`.
- Creer que un subagente nunca lanza otros: un subagente **sin** línea `tools` (o con `Agent` en ella)
  sí lanzó un subagente `general-purpose` en 2.1.332. El auditor no puede porque su `tools` no incluye `Agent`.
- `claude -p` fuera de la raíz del repo o en una carpeta sin confianza: las reglas `allow` del
  proyecto se ignoran (`Ignoring N permissions.allow entries…`, visto en la Sesión 2).
- `%` sin escapar en crontab (`$(date +%F)`): corta la línea. Que la fecha la ponga la skill.
- Laptop del instructor con un hook `PermissionRequest` o con modo auto por defecto: en la demo
  aparece `Allowed by PermissionRequest hook` o `Allowed by auto mode` y no se ve el diálogo de
  permisos que verán los alumnos. `Shift+Tab` hasta `manual mode` (y sin el hook) para mostrarlo.

## 5. Windows (Git Bash)
- `claude mcp add ... -- node herramientas/mcp-inventario/index.js` igual que en macOS, si `node`
  está en el PATH de Git Bash (`which node`). No probado en Windows.
- `.gitattributes` fuerza LF; el servidor de todos modos acepta CRLF en el CSV.
- Programador de tareas (no probado): programa `C:\Program Files\Git\bin\bash.exe`, argumentos
  `-lc "cd ~/edf-ti-practica && mkdir -p reportes && claude -p 'Usa la skill auditoria-diaria' --allowedTools 'Read,Grep,Glob,Write,Bash(./scripts/revisa-secretos.sh *),Bash(git status *)' >> reportes/cron.log 2>&1"`.
  `-l` carga el PATH del perfil. Ahí `%` no necesita escape.
- La regla de `\%` es solo de cron.

## 6. Sin Docker
Todo el Laboratorio A y la Base del B se hacen sin Docker. Solo el Avanzado de respaldos necesita la base.

## 7. Tiempos sugeridos (laboratorio)

| Laboratorio | Minutos |
|---|---|
| A Base: Prompt 2 en modo plan (plan 1 a 2 min, construcción y prueba 3 a 5 min con aprobaciones) | 12 |
| A Base: registrar, reiniciar, `/mcp`, pregunta del paso 3 | 8 |
| A Avanzado: Prompts 3 y 1, `/clear`, prueba | 5 (o tarea de quien terminó) |
| B Base: `auditor.md`, Prompt 4 | 10 |
| B Base: `claude -p` (unos 60 s por corrida, 1 a 3 corridas) y commit | 10 |
| B Avanzado: cron, respaldos o plugin (uno, no los tres) | 15 |

Avanzado si sobra tiempo: la skill del reporte (A), y cron, respaldos o plugin (B).
Al terminar: `docker compose stop` (nunca `down -v`), y quitar el plugin y el crontab de prueba.
