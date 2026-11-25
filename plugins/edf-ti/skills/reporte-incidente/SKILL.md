---
name: reporte-incidente
description: Convierte una línea del tiempo de un incidente en el reporte estándar de TI para la dirección. Úsala cuando pidan un reporte, postmortem, informe o resumen de incidente, o «qué pasó anoche».
---
1. Lee la línea del tiempo que te indiquen. Si no indican ninguna, usa
   `incidente/linea-del-tiempo.md`. No abras los logs crudos salvo que lo pidan.
2. Llena `plantilla.md` (en esta misma carpeta), sin inventar datos:
   - Cada hecho lleva su evidencia (`archivo:línea`), copiada de la línea del tiempo.
   - Lo que no esté en la evidencia va como `[pendiente]`: responsables, fechas de
     las acciones, impacto en el negocio, lo que hizo el atacante dentro de la sesión.
   - Horas en una sola zona horaria. Si la línea del tiempo corrigió un reloj, usa
     las horas corregidas y dilo en el reporte.
   - Español claro, para alguien que no lee logs. Nada de valores de secretos.
3. Guarda en `reportes/incidente-AAAA-MM-DD.md`, con la fecha en que empezó el
   incidente. Si ya existe, pregunta antes de reemplazarlo.
4. Al terminar, di la ruta del archivo y cuántos `[pendiente]` quedaron.
