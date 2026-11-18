#!/usr/bin/env bash
# rota-logs.sh - Rota y comprime los logs de logs/ con más de 7 días.
# Uso: ./scripts/rota-logs.sh [dias]   (por defecto: 7)
set -euo pipefail

DIAS="${1:-7}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="$RAIZ/logs"
FECHA="$(date +%Y%m%d)"

if [ ! -d "$LOGS" ]; then
  echo "No existe la carpeta $LOGS; nada que rotar."
  exit 0
fi

ROTADOS=0
# Buscar archivos .log con más de N días (find -mtime funciona en BSD y GNU)
while IFS= read -r LOG; do
  # Renombrar con la fecha de rotación y comprimir
  DESTINO="${LOG%.log}-$FECHA.log"
  mv "$LOG" "$DESTINO"
  gzip -f "$DESTINO"
  echo "Rotado: $(basename "$DESTINO").gz"
  ROTADOS=$((ROTADOS + 1))
done < <(find "$LOGS" -type f -name '*.log' -mtime +"$DIAS")

echo "Logs rotados: $ROTADOS"
