# Plan: `scripts/revisa-secretos.sh`

Plan con el que se construyó el revisor de secretos (ejercicio 3 de la Sesión 1).
Al final están los ajustes que salieron al implementarlo y el resultado de las pruebas.

## Cómo se usa

- `./scripts/revisa-secretos.sh [carpeta]`. Sin carpeta, revisa la actual.
- Una línea por hallazgo, `ruta:línea: tipo`. Nunca imprime el valor ni el texto de la línea.
- Al final, el total de cada tipo (también los que dan 0) y el total general.
- Código de salida: 0 sin hallazgos, 1 con hallazgos y 2 si hubo un error, como una carpeta que no existe.
- Solo lee: no mueve, no cambia ni envía nada.

## 1. Cómo se detecta cada tipo

| Tipo | Cómo se detecta | Qué no cuenta |
|---|---|---|
| `archivo-env` | Por el nombre: `.env`, `.env.<algo>` o `<algo>.env`. Un hallazgo por archivo, en la primera línea con valor. Sus líneas también pasan por las reglas de contraseña y token. | Plantillas (nombres que terminan en `.example`, `.sample`, `.template` o `.dist`) y archivos sin valores |
| `llave-privada` | Por el contenido: la línea `-----BEGIN … PRIVATE KEY` (RSA, EC, OpenSSH, cifradas, PGP) y la cabecera de las llaves de PuTTY. La encuentra aunque esté renombrada o dentro de un JSON. | Llaves públicas (`.pub`) |
| `contraseña` | Un nombre que termina en `password`, `passwd`, `pwd` o `contraseña`, seguido de `=`, `:`, `:=` o `=>` y de un valor literal. Cubre shell, `.env`, `.conf`, YAML, JSON, JavaScript y Python. También la asignación con `$` de PowerShell y PHP, y `ConvertTo-SecureString` con texto fijo y `-AsPlainText`. | Valor vacío; una variable que se lee (`"$DB_PASSWORD"`, `${…}`, `%VAR%`); código (`process.env.X`, `os.environ[…]`); un marcador (`CAMBIAR_EN_EL_SERVIDOR`, `changeme`, `xxx`, `<…>`); menos de 4 caracteres; o un valor sin comillas con más palabras después de `:`, que es una nota en texto |
| `token` | La misma regla con `token`, `secret`, `api_key`, `access_key` y `client_secret`; un `Bearer` con valor literal; y formatos conocidos aunque el nombre no los delate: AWS, GitHub, Slack, Google, Stripe y JWT. | Lo mismo que en contraseña |
| `credencial-en-url` | `esquema://usuario:contraseña@servidor`, como una cadena de conexión de PostgreSQL | Que la contraseña sea una variable o un marcador |

La palabra clave tiene que cerrar el nombre o ir seguida de `_` o `-`: así cuentan
`DB_PASSWORD` y `TOKEN_WEBHOOK`, pero no `secretaria`, `tokens` ni `passwordless`.

**Solo con bash y grep:**

- Dos búsquedas con `grep -r`: una lista los archivos, para reconocer los `.env` por su nombre; otra saca las líneas candidatas, y bash decide cuáles son hallazgos.
- Compatible con el bash 3.2 que trae macOS.
- Solo opciones de grep que existen en macOS y en Linux: sin `-P`, `\s`, `\b` ni `--include`.
- Los nombres de archivo van separados por un byte nulo, así que las rutas con espacios no rompen nada.
- `LC_ALL=C`, para que grep no tome por binario un archivo con acentos mal codificados.
- No revisa `.git/`, `node_modules/`, `.venv/`, `venv/` ni a sí mismo.

## 2. Falsos positivos esperados

- Un `.env` que está en `.gitignore` también sale: se revisa la carpeta, no lo que está en Git.
- Un `.env` con pura configuración inofensiva sale como `archivo-env`. Es a propósito: ese archivo no debería estar en el repositorio.
- Valores de ejemplo que no están en la lista de marcadores, como una contraseña de ejemplo escrita en una documentación.
- Credenciales en líneas comentadas. También es a propósito: comentadas siguen expuestas.
- En bash, comparar una variable con un valor fijo escrito en el script se ve igual que una asignación de PowerShell y sale.

**Lo que no detecta:**

- Secretos con un nombre inocente y sin formato conocido.
- Contraseñas pasadas como argumento con espacio (`--password …`, `mysql -p…`, `curl -u …`).
- El historial de Git: un secreto borrado en un commit posterior sigue ahí.
- Binarios, archivos en UTF-16, comprimidos y contenedores de llaves (`.pfx`, `.p12`, `.jks`).
- Contraseñas sin comillas con forma de código (`Clave.Segura`) y frases sin comillas después de `:`.

## 3. Supuestos sin verificar

- macOS: está escrito para el bash 3.2 y el grep de macOS, pero no se ha ejecutado ahí.
- Los valores de los `.env` de este repositorio no se leyeron.
- Los archivos son texto en UTF-8 o ASCII.
- Está pensado para un repositorio; no se midió en carpetas enormes.

## 4. Pruebas

1. **Carpeta temporal con secretos falsos.** Cada uno lleva una marca que nunca debe aparecer en la salida. Incluye un caso por tipo, uno por cada falso positivo conocido, rutas con espacios, finales de línea de Windows, un binario y carpetas `.git/`, `node_modules/` y `.venv/`. Se comprueban:
   - la lista exacta de hallazgos;
   - que la marca no aparezca;
   - el formato de cada línea y el resumen;
   - los códigos de salida: 1 con hallazgos, 0 en una carpeta limpia, y 2 con una carpeta inexistente o con argumentos de más.
2. **En este repositorio**, los 9 hallazgos esperados:

   | Ruta | Línea | Tipo |
   |---|---|---|
   | `.env` | 2 | archivo-env |
   | `.env` | 4 | contraseña |
   | `.env` | 5 | token |
   | `config/.env.produccion` | 2 | archivo-env |
   | `config/.env.produccion` | 4 | contraseña |
   | `config/.env.produccion` | 5 | token |
   | `config/app.conf` | 16 | contraseña |
   | `scripts/notifica.sh` | 10 | token |
   | `llaves/id_practica` | 1 | llave-privada |

## Ajustes al implementarlo

Cambios respecto al plan, encontrados al escribir y probar el script:

- Un valor entre comillas seguido de `;` o `,`, como en JavaScript o PHP, no se detectaba. Lo encontró la prueba y quedó corregido.
- Tampoco se revisan `.venv/` ni `venv/`.
- No cuentan los nombres que describen el secreto en vez de contenerlo, como `TOKEN_URL`, `PASSWORD_FILE` o `token_ttl`.
- No cuentan los valores que son una ruta (`/run/secrets/…`) o una URL sin credenciales.
- Dentro de una cadena de conexión escrita en el código, la contraseña sí cuenta aunque no lleve comillas propias.
- Las llaves de ejemplo de la documentación de AWS (las que dicen `EXAMPLE`) no cuentan.
- Un `Bearer` necesita al menos 8 caracteres con forma de token.

## Resultado

- Git Bash (bash 5.3 y GNU grep 3.0): 16 de 16 comprobaciones.
- Ubuntu 24.04 en WSL (bash 5.2 y GNU grep 3.11): 16 de 16.
- Este repositorio: los 9 hallazgos esperados, sin falsos positivos.
- macOS: pendiente.
