# Prompts de la Sesión 1

Los prompts de la práctica (11 de noviembre de 2026), en el orden de los ejercicios del
README. Debajo de cada uno está lo que Claude Code ejecutó y lo que salió. Ningún
resultado incluye el valor de un secreto.

Todos se mandaron en modo automático, desde una sesión de Claude Code abierta en
`C:\Users\Usuario`, fuera del repositorio.

## 0. Clonar el repositorio

> CLONA ESTE REPOSITORIO LLAMADO EDF-TI-PRACTICA

**Lo que se corrió:**

- `gh search repos EDF-TI-PRACTICA`: lo encontró como `F-Urquizo/edf-ti-practica`, público.
- `gh repo view F-Urquizo/edf-ti-practica`: la rama principal es `main`.
- `git clone https://github.com/F-Urquizo/edf-ti-practica.git` en el escritorio y `git log --oneline -5`.
- Leyó el `README.md`.

**Resultado:** el repositorio quedó en `Desktop\edf-ti-practica`, en `main` (`69f0883`).

Después se pidió el enlace:

> DAME EL LINK DEL REPOSITORIO

Claude respondió sin ejecutar nada: https://github.com/F-Urquizo/edf-ti-practica

## 1. Que Claude explique el repositorio

> EXPLÍCAME EL REPOSITORIO

**Lo que se corrió:**

- `git ls-files`, `find` y `git log --stat`: los archivos versionados, los que hay en disco y el historial.
- Leyó `.gitignore`, `.gitattributes`, los tres scripts, `config/app.conf`, el inventario y los logs.
- De los dos `.env` mostró solo los nombres de las variables (`grep … | cut -d= -f1`). De `llaves/` mostró solo el tipo de llave.
- `git show df1d2fe f5e1d0b -- scripts/respaldo.sh`: los dos últimos cambios al script de respaldo.

**Resultado:** la explicación de cada archivo y de dónde están los secretos sembrados, sin mostrar valores.

**Ojo:** las reglas del ejercicio 2 todavía no existían. Claude abrió `config/app.conf`, que trae
una contraseña (no la mostró), y los `.env` pasaron por `grep` para sacar los nombres.

## 2. Reglas `deny` en `.claude/settings.json`

**2.1. Crear las reglas.** Se pegó este contenido para `.claude/settings.json`:

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": [
      "Bash(git status)",
      "Bash(git diff *)",
      "Bash(git log *)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(docker *)",
      "Bash(systemctl *)",
      "Bash(ssh *)"
    ],
    "deny": [
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/llaves/**)",
      "Read(~/.ssh/**)",
      "Bash(cat .env*)",
      "Bash(rm -rf *)"
    ]
  }
}
```

**Lo que se corrió:**

- Creó `.claude/settings.json` con ese contenido y comprobó que es JSON válido: 3 reglas `allow`, 4 `ask` y 6 `deny`.
- En la misma sesión, `cat .env.example` sí funcionó. Las reglas de un repositorio solo se aplican
  en una sesión abierta dentro de él, y esta se abrió en `C:\Users\Usuario`.
- Para probarlas, abrió una sesión nueva dentro del repositorio, sin interacción:
  `claude -p "…" --model haiku --output-format json --no-session-persistence --allowedTools "Read" "Bash(cat *)" "Bash(head *)"`.
  Le pidió leer `.env.example` con `Read`, con `cat` y con `head`, y revisó el campo `permission_denials`
  de la respuesta. Se probó con `.env.example`, que no tiene secretos, por si la regla fallaba.

**Resultado:**

- La lectura con `Read` quedó bloqueada por `Read(**/.env.*)`, aunque `--allowedTools` la permitía: una regla `deny` gana.
- Claude Code ignoró las 3 reglas `allow` porque la carpeta todavía no estaba marcada como de confianza.
  Las `deny` sí se aplicaron.
- Esa sesión tenía PowerShell en lugar de la herramienta Bash, así que `Bash(cat .env*)` no se pudo probar.
  Las reglas `Bash(...)` no cubren los comandos de PowerShell.

**2.2. Comprobar que Claude no puede leer los secretos.**

> Lee el archivo .env y la llave que está en la carpeta llaves/ y dime qué contienen.

**Lo que se corrió:** nada. Claude no leyó los archivos porque las reglas recién creadas lo prohíben,
aunque en esa sesión no estaban activas, y ofreció hacerlo solo con una autorización explícita.
La prueba de que las reglas funcionan es la del punto 2.1.

**2.3. Extra: plantilla de variables sin leer los `.env`.**

> Sin leer ningún archivo .env, busca en el código y en los scripts qué variables de entorno usa este proyecto. Crea un archivo .env.example con cada variable, un valor ficticio y un comentario de para qué sirve. Si una variable parece una credencial, ponle de valor CAMBIAR_EN_EL_SERVIDOR.

**Lo que se corrió:**

- Buscó con `grep` las variables que usan `scripts/*.sh` y `config/app.conf` (`$VAR` y `${VAR}`)
  y las que menciona el README. No abrió ningún `.env`.
- Solo `scripts/respaldo.sh` lee variables de entorno: `DB_HOST`, `DB_USER` y `DB_PASSWORD`.
  `PGPASSWORD` se arma ahí mismo para un solo comando. `scripts/notifica.sh` trae su token y su URL
  escritos dentro del script.
- Creó `.env.example` con las tres variables, un valor ficticio y un comentario para cada una.
  `DB_PASSWORD` quedó con `CAMBIAR_EN_EL_SERVIDOR`.

**Notas del ejercicio 2:**

- `Read(**/.env.*)` también bloquea `.env.example`: en una sesión abierta en el repositorio, Claude no puede leer la plantilla.
- Las reglas no cubren `config/app.conf` ni `scripts/notifica.sh`, que también tienen secretos sembrados.
- `.claude/settings.json` y `.env.example` entraron a la rama al final, en su propio commit (ver «Cierre»).

## 3. Plan de `scripts/revisa-secretos.sh`

> Quiero un script scripts/revisa-secretos.sh que revise una carpeta (por omisión, la actual) y encuentre posibles secretos expuestos: archivos .env, llaves privadas, y tokens o contraseñas escritos en el código. Para cada hallazgo debe imprimir la ruta, el número de línea y el tipo de hallazgo, pero nunca el valor. Al final, un resumen con el total por tipo, y que termine con código 1 si encontró algo. Solo bash y grep, sin instalar nada, y que funcione en macOS y en Linux. Antes de escribir nada, dame el plan: cómo vas a detectar cada tipo, qué falsos positivos esperas, qué supones que no verificaste y cómo lo pruebo.

**Lo que se corrió:** solo revisó el entorno, sin escribir nada.

- Las versiones de Git Bash (bash 5.3 y GNU grep 3.0), y que existieran las opciones de grep que iba a usar.
- La lista de archivos del repositorio, sin abrir los `.env`.
- `wsl -l -v`: hay un Ubuntu 24.04 para probar en Linux.

**Resultado:** el plan, que está en [plan-revisa-secretos.md](plan-revisa-secretos.md).

El prompt se mandó dos veces igual. La segunda vez el plan agregó las asignaciones de PowerShell y PHP.

El README pide hacer este ejercicio en modo plan (`Shift+Tab`), y aquí no se usó: el plan se pidió
en el mismo prompt («Antes de escribir nada, dame el plan») con la sesión en modo automático.

## 4. Ejecutar el revisor

**Prompt sugerido.** No se mandó así: Claude hizo este ejercicio cuando se le pidió completar los que faltaban (ver «Cierre»).

> Ejecuta scripts/revisa-secretos.sh en la raíz del repositorio y dime qué encontró, sin mostrar ningún valor.

**Lo que se corrió:** `bash scripts/revisa-secretos.sh` en la raíz del repositorio, en la rama `herramienta/revisa-secretos`.

**Resultado:** los 9 secretos sembrados, con código de salida 1.

```
.env:2: archivo-env
config/.env.produccion:2: archivo-env
.env:4: contraseña
.env:5: token
config/.env.produccion:4: contraseña
config/.env.produccion:5: token
config/app.conf:16: contraseña
llaves/id_practica:1: llave-privada
scripts/notifica.sh:10: token

Resumen:
     2  archivo-env
     1  llave-privada
     3  contraseña
     3  token
     0  credencial-en-url
     9  total
```

## 5. Commit en una rama nueva y regla en `CLAUDE.md`

> Crea una rama llamada herramienta/revisa-secretos, agrega solo scripts/revisa-secretos.sh y haz un commit con un mensaje que diga qué hace y por qué. Después agrega al CLAUDE.md (créalo si no existe) esta regla: antes de cada commit, correr scripts/revisa-secretos.sh. Muéstrame el diff antes del segundo commit.

A media tarea se agregó:

> tambien manda los prompts que faltaron ala rama ordenado por numeros y el plan

**Lo que se corrió:**

1. `git status`, `git config user.name` y `git config user.email`: Git no tenía nombre ni correo
   configurados. Los commits se firmaron con `git -c user.name=… -c user.email=…`, sin cambiar la configuración.
2. Escribió `scripts/revisa-secretos.sh` según el plan.
3. Lo probó con una carpeta temporal fuera del repositorio, con secretos falsos: 26 hallazgos
   esperados, una marca que nunca debe aparecer en la salida y los casos de error. La primera
   corrida encontró dos fallas, que se corrigieron:
   - no detectaba un valor entre comillas seguido de `;`, como en JavaScript o PHP;
   - un comentario del propio script salía como hallazgo.
4. Ya corregido: 16 de 16 comprobaciones en Git Bash y 16 de 16 en Ubuntu 24.04 (`wsl -d Ubuntu-24.04 -- bash …`).
5. `bash scripts/revisa-secretos.sh` en el repositorio: los 9 hallazgos esperados.
6. `git switch -c herramienta/revisa-secretos`, `git add --chmod=+x scripts/revisa-secretos.sh` y el primer commit: `3b0f09b`.
7. Creó `CLAUDE.md` con la regla y mostró `git diff --cached -- CLAUDE.md` antes del segundo commit.
8. Escribió este archivo y el plan en `docs/`.
9. Con el diff ya revisado, corrió el revisor (los mismos 9 hallazgos, ninguno nuevo) e hizo el
   segundo commit, solo con `CLAUDE.md`: `2ea471e`.

**Resultado:** la rama `herramienta/revisa-secretos` con el script ejecutable (`3b0f09b`) y la regla en `CLAUDE.md` (`2ea471e`).

## 6. Un cambio malo a propósito y `git restore`

**Prompt sugerido.** No se mandó así: Claude hizo este ejercicio cuando se le pidió completar los que faltaban (ver «Cierre»).

> Haz a propósito un cambio malo en scripts/rota-logs.sh, muéstrame el diff y luego deshazlo con git restore. Confirma que el archivo quedó igual que en el último commit.

**Lo que se corrió:**

1. En `scripts/rota-logs.sh` cambió `-mtime +"$DIAS"` por `-mtime -"$DIAS"`. Con eso el script
   comprimiría los logs de los últimos 7 días, que siguen en uso, en vez de los viejos.
   El script no se ejecutó.
2. `git diff -- scripts/rota-logs.sh`:

   ```diff
   -done < <(find "$LOGS" -type f -name '*.log' -mtime +"$DIAS")
   +done < <(find "$LOGS" -type f -name '*.log' -mtime -"$DIAS")
   ```

3. `bash -n scripts/rota-logs.sh` dijo que la sintaxis está bien: este error solo se ve leyendo el diff.
4. `git restore scripts/rota-logs.sh`.
5. Comprobación: `git diff --quiet` no encontró diferencias, y `git hash-object scripts/rota-logs.sh`
   da lo mismo que `git rev-parse HEAD:scripts/rota-logs.sh` (`b080e08`).

**Resultado:** el archivo quedó idéntico al del último commit. Los archivos preparados para el
siguiente commit no se tocaron: `git restore` con una ruta solo cambia ese archivo.

## Cierre: documentar y subir

> sube el de docs y tambien agrega lo que corrimos en cada pront si falta alguno realizalo y despues lo subes

**Lo que se corrió:**

- Reconstruyó, con el registro de la sesión, lo que se ejecutó en cada prompt y lo agregó a este archivo.
- Hizo los ejercicios que faltaban: el 4 y el 6.
- Antes de cada commit corrió `scripts/revisa-secretos.sh`, como pide `CLAUDE.md`.
- Hizo el segundo commit (`CLAUDE.md`) y el tercero (`docs/`).
- `gh api repos/F-Urquizo/edf-ti-practica`: la cuenta de GitHub de esta PC no tiene permiso de
  escritura en el repositorio del curso, así que la rama no se puede subir ahí.
- Se eligió subirla al fork `BackDevEDF/edf-ti-practica` como `Milton-herramienta/revisa-secretos`,
  con el mismo formato de nombre que la otra rama del fork. `git push` respondió con un error 403:
  la cuenta tampoco tiene permiso de escritura en ese fork.

> si subelo como emma lo subio

**Lo que se corrió:**

- Comprobó que `.claude/settings.json` es idéntico al contenido pegado en el punto 2.1, y que
  `.env.example` solo trae `DB_HOST`, `DB_USER` y `DB_PASSWORD`, con la contraseña como marcador.
- Los agregó a la rama en un cuarto commit. La otra rama del fork también lleva su `.env.example`.
- Revisó otra vez el permiso en el fork: la cuenta sigue sin acceso de escritura y no tiene
  invitaciones pendientes. Para subir la rama, la cuenta `BackDevEDF` tiene que agregar a
  `miltoncendejas-sys` como colaborador del fork.

> subelo y dejalo como solicitud para que la otra persona lo aprueve

**Lo que se corrió:**

- `gh repo fork BackDevEDF/edf-ti-practica --default-branch-only`: un fork propio en la cuenta
  `miltoncendejas-sys`, donde sí puede escribir.
- Subió ahí la rama como `Milton-herramienta/revisa-secretos`.
- `gh pr create`: abrió una solicitud de cambios (pull request) de esa rama hacia `main` de
  `BackDevEDF/edf-ti-practica`, para que el dueño del fork la revise y la apruebe.

## Fuera de los ejercicios

> HAZME UNA BARRA DE CONTEXTO EN LAS SESIONES DE TRABAJO

Se configuró la línea de estado de Claude Code en la configuración personal (`~/.claude/settings.json`),
no en este repositorio. Muestra el modelo, la carpeta y una barra con el contexto usado.
