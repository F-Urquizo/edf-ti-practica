---
name: auditoria-diaria
description: Auditoría diaria del repositorio con el subagente auditor (secretos expuestos, reglas de permisos y cambios sin commit). Deja el reporte en reportes/. Úsala cuando pidan la auditoría diaria, auditar o revisar el repositorio.
---
Solo revisas y reportas. No corrijas nada, no hagas commit y no cambies ningún archivo
fuera de `reportes/`.

1. Delega la revisión al subagente `auditor`. No la hagas tú ni corras sus comandos por tu cuenta.
2. Con su respuesta, escribe `reportes/auditoria-AAAA-MM-DD.md` con la fecha de hoy, que ya
   tienes en tu contexto (no corras `date`). Si el archivo ya existe, reemplázalo.
3. Formato del reporte:
   - **Primera línea, sola:** `OK` si no hubo hallazgos, o `N hallazgos` (por ejemplo `5 hallazgos`).
     Cuenta cada hallazgo del auditor: los secretos, cada regla que falte y los cambios sin commit.
   - Una línea en blanco y una tabla: `| Hallazgo | Archivo | Gravedad |`, una fila por hallazgo,
     sin copiar el valor de ningún secreto.
   - Al final: `Generado por la skill auditoria-diaria el AAAA-MM-DD.`
4. Responde solo con la ruta del reporte y su primera línea.
