# CLAUDE.md

Repositorio de práctica del curso de Claude Code para TI de EDF: simula los scripts operativos
de un equipo de TI (respaldos, rotación de logs, notificaciones). Todos los datos son ficticios.
Este archivo es solo el índice; el detalle está en `docs/`.

## Dónde mirar
| Si vas a... | Lee |
|---|---|
| usar o cambiar un script, o ver sus problemas conocidos | `docs/scripts.md` |
| hablar de servidores, entornos o responsables | `docs/servidores.md` |
| preguntarte por qué algo está así | `docs/decisiones.md` |
| escribir bash | `.claude/rules/scripts.md` (se carga sola al tocar `scripts/**/*.sh`) |

## Reglas que siempre aplican
- Todo en español: comentarios, mensajes de commit y documentación.
- Las credenciales se leen de variables de entorno, nunca se escriben en el código.
- Trabaja en una rama; no hagas commit directo a `main`.
- No leas, muestres ni copies credenciales: archivos `.env*`, la carpeta `llaves/`,
  `~/.ssh/` ni valores de tokens o contraseñas. Si necesitas saber si una variable
  existe, pregunta o revisa el nombre, nunca el valor.

## Antes de cada commit
- Ejecuta `./scripts/revisa-secretos.sh`. Si encuentra algo nuevo (código de salida 1
  con hallazgos que no sean los 5 sembrados para la práctica), no hagas commit y avísame.

## Mantener la documentación
- Si cambias un script, actualiza `docs/scripts.md` en el mismo commit.
- Si tomas una decisión que explique por qué algo es así, agrégala a `docs/decisiones.md`.
- Si cambia `docs/inventario-servidores.csv`, actualiza `docs/servidores.md`.
