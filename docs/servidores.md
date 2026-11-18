# Servidores

Resumen del inventario de `docs/inventario-servidores.csv`, que es la fuente de verdad: si
cambia el CSV, actualiza este archivo. Todos los datos son **ficticios**. El inventario no trae
direcciones IP, puertos ni credenciales, y este documento tampoco debe llevarlos.

Columnas del CSV: `nombre`, `rol`, `sistema_operativo`, `entorno`, `responsable`.

## Por entorno (10 servidores)

### Producción (7)

| Servidor | Rol | Sistema operativo | Responsable |
|---|---|---|---|
| `srv-app-prod-01` | servidor de aplicaciones | RHEL 9.2 | Equipo Operaciones TI |
| `srv-app-prod-02` | servidor de aplicaciones | RHEL 9.2 | Equipo Operaciones TI |
| `db-prod-01` | base de datos PostgreSQL | RHEL 9.2 | Equipo Datos |
| `srv-batch-prod-01` | procesos batch nocturnos | RHEL 8.8 | Equipo Operaciones TI |
| `srv-respaldos-01` | almacenamiento de respaldos | Ubuntu 20.04 LTS | Equipo Infraestructura |
| `srv-monitoreo-01` | monitoreo y alertas | Debian 12 | Equipo Infraestructura |
| `srv-ad-01` | controlador de dominio | Windows Server 2022 | Equipo Infraestructura |

### QA (1)

| Servidor | Rol | Sistema operativo | Responsable |
|---|---|---|---|
| `srv-web-qa-01` | servidor web Nginx | Debian 12 | Equipo Desarrollo |

### Desarrollo (2)

| Servidor | Rol | Sistema operativo | Responsable |
|---|---|---|---|
| `srv-app-dev-01` | servidor de aplicaciones | Ubuntu 22.04 LTS | Equipo Desarrollo |
| `db-dev-01` | base de datos PostgreSQL | Ubuntu 22.04 LTS | Equipo Datos |

## Por responsable

| Equipo | Servidores |
|---|---|
| Operaciones TI | 3 (`srv-app-prod-01`, `srv-app-prod-02`, `srv-batch-prod-01`) |
| Infraestructura | 3 (`srv-respaldos-01`, `srv-monitoreo-01`, `srv-ad-01`) |
| Desarrollo | 2 (`srv-app-dev-01`, `srv-web-qa-01`) |
| Datos | 2 (`db-dev-01`, `db-prod-01`) |

## Por sistema operativo

RHEL 9.2 (3), Ubuntu 22.04 LTS (2), Debian 12 (2), RHEL 8.8 (1), Ubuntu 20.04 LTS (1),
Windows Server 2022 (1).

## Observaciones

Son lecturas del CSV, no hechos confirmados: conviene validarlas con los responsables.

- `srv-respaldos-01` corre Ubuntu 20.04 LTS, la versión más antigua del inventario, y está en
  producción. Verifica si sigue dentro del soporte del proveedor.
- `srv-batch-prod-01` usa RHEL 8.8; el resto de los RHEL están en 9.2.
- Solo hay un servidor de respaldos y un controlador de dominio listados. El inventario no dice
  si existen réplicas fuera de él.
- `scripts/respaldo.sh` usa `pg_dump` contra el servidor que indique `DB_HOST`. El repositorio
  no dice cuál es: lo define quien ejecuta el script. Las únicas bases PostgreSQL del
  inventario son `db-dev-01` y `db-prod-01`.
- No hay servidores de QA para base de datos ni para batch.
