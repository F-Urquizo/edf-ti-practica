# edf-ti-practica

## Antes de cada commit

Antes de cada commit, correr `scripts/revisa-secretos.sh`.

Este repo tiene secretos ficticios sembrados a propósito, así que el script sale con 1.
Lo que importa es que no aparezca ningún hallazgo fuera de los esperados
(`.env`, `config/.env.produccion`, `llaves/id_practica`, `scripts/notifica.sh` y `config/app.conf`).
Si aparece algo más, no hacer el commit y avisar.
