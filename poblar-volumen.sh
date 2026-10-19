#!/bin/bash
# Llena el network volume con lo de modelos.txt. Se corre UNA vez en un pod
# temporal de RunPod con el volumen montado (en un pod se monta en /workspace;
# el worker serverless lo ve en /runpod-volume).
#
#   bash poblar-volumen.sh /workspace
#
# Reanudable: wget -c retoma lo que quedó a medias. Al final compara el tamaño
# de cada fichero contra el que anuncia Hugging Face; un 0 de wget no basta.
set -euo pipefail
RAIZ="${1:?uso: poblar-volumen.sh <punto de montaje del volumen>}"
LISTA="$(dirname "$0")/modelos.txt"

# Primero lo retirado (retirados.txt: «carpeta fichero»), para hacer sitio.
RETIRADOS="$(dirname "$0")/retirados.txt"
if [[ -f "$RETIRADOS" ]]; then
  while read -r carpeta fichero; do
    [[ -z "$carpeta" || "$carpeta" == \#* ]] && continue
    if [[ -e "$RAIZ/models/$carpeta/$fichero" ]]; then
      echo "== retiro $carpeta/$fichero"; rm -f "$RAIZ/models/$carpeta/$fichero"
    fi
  done < "$RETIRADOS"
fi
df -h "$RAIZ" || true

fallos=0
while read -r carpeta url; do
  [[ -z "$carpeta" || "$carpeta" == \#* ]] && continue
  destino="$RAIZ/models/$carpeta/$(basename "$url")"
  mkdir -p "$(dirname "$destino")"
  echo "== $carpeta/$(basename "$url")"
  wget -nv -c -O "$destino" "$url"
  # Los ficheros chicos (no LFS) no traen x-linked-size: con pipefail el grep
  # vacío tumbaba el script entero, así que aquí no cuenta como fallo.
  esperado=$(curl -sIL "$url" | grep -i '^x-linked-size:' | tail -1 | tr -dc '0-9' || true)
  real=$(stat -c %s "$destino")
  if [[ -n "$esperado" && "$esperado" != "$real" ]]; then
    echo "   TAMAÑO DISTINTO: esperado $esperado, en disco $real"; fallos=$((fallos+1))
  fi
done < "$LISTA"

du -sh "$RAIZ/models"
[[ $fallos -eq 0 ]] && echo "OK: volumen completo" || { echo "$fallos ficheros con tamaño distinto"; exit 1; }
