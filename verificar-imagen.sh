#!/bin/bash
# Corre dentro del build. Si algo falla, la imagen NO se publica.
# No basta con que el `pip install` devuelva 0: se arranca ComfyUI y se lee
# qué nodos cargó de verdad.
set -euo pipefail

echo "== 1. torch y compañía siguen siendo los de la base"
uv pip freeze | grep -iE '^(torch|torchvision|torchaudio|transformers|huggingface-hub)==' \
  | diff /opt/candado-base.txt - \
  || { echo "FALLO: un requirements cambió versiones congeladas"; exit 1; }

echo "== 2. el ComfyUI de la base sabe hacer Qwen-Image-Edit 2511"
grep -q 'TextEncodeQwenImageEditPlus' /comfyui/comfy_extras/nodes_qwen.py \
  || { echo "FALLO: este ComfyUI no trae TextEncodeQwenImageEditPlus"; exit 1; }

echo "== 3. ComfyUI arranca (CPU) y carga los cuatro nodos"
cd /comfyui
python main.py --cpu --quick-test-for-ci > /tmp/arranque.log 2>&1 || true
grep -A40 'Import times for custom nodes' /tmp/arranque.log || true
# Solo los de custom_nodes: algún extra del núcleo puede no importar en CPU y
# eso no es asunto de esta imagen.
if grep -q 'IMPORT FAILED): /comfyui/custom_nodes/' /tmp/arranque.log; then
  echo "FALLO: hay nodos propios que no importaron"
  grep -B30 'IMPORT FAILED): /comfyui/custom_nodes/' /tmp/arranque.log; exit 1
fi
for n in ComfyUI-WanVideoWrapper ComfyUI-KJNodes ComfyUI-VideoHelperSuite ComfyUI-Chatterbox; do
  grep -qE "seconds: /comfyui/custom_nodes/$n\$" /tmp/arranque.log \
    || { echo "FALLO: $n no aparece como cargado"; tail -60 /tmp/arranque.log; exit 1; }
done
echo "OK: imagen verificada"
