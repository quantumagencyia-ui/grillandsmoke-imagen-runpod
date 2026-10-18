# Imagen de RunPod serverless para Grill & Smoke: worker-comfyui + los nodos de
# InfiniteTalk, Wan 2.2, Qwen-Image-Edit-2511 y Chatterbox.
#
# Los MODELOS NO VAN AQUÍ. Son ~91 GB y viven en el network volume
# (/runpod-volume/models en serverless); ver modelos.txt y poblar-volumen.sh.
# Un runner de GitHub tiene ~14 GB libres: hornearlos no cabe.
#
# 5.11.0 tiene release en GitHub pero no imagen en Docker Hub (18-oct-2026).
ARG BASE=runpod/worker-comfyui:5.10.0-base-cuda12.8.1
FROM ${BASE}

# Nodos fijados por commit: reconstruir tiene que dar la misma imagen.
ARG WANVIDEO_SHA=088128b224242e110d3906c6750e9a3a348a659b
ARG KJNODES_SHA=17195fcfa8a05f601b766a0f09c9733284f47416
ARG VHS_SHA=4d907bee61e92c2e65af3bd6383a4e4d356126d1
ARG CHATTERBOX_SHA=4597af8f59d4460d441e13533eae24b092e40952

# Un nodo con un requirements suelto puede subir torch a una build cu13 que no
# arranca en los hosts de RunPod (driver 570/575). Se congelan las versiones que
# trae la base y se instalan los requirements contra ese candado.
RUN uv pip freeze | grep -iE '^(torch|torchvision|torchaudio|transformers|huggingface-hub)==' \
      > /opt/candado-base.txt \
    && cat /opt/candado-base.txt \
    && test "$(wc -l < /opt/candado-base.txt)" -eq 5

WORKDIR /comfyui/custom_nodes
RUN set -e; \
    clonar() { git clone -q "https://github.com/$1.git" "$2" && git -C "$2" checkout -q "$3"; }; \
    clonar kijai/ComfyUI-WanVideoWrapper         ComfyUI-WanVideoWrapper      "$WANVIDEO_SHA"; \
    clonar kijai/ComfyUI-KJNodes                 ComfyUI-KJNodes              "$KJNODES_SHA"; \
    clonar Kosinkadink/ComfyUI-VideoHelperSuite  ComfyUI-VideoHelperSuite     "$VHS_SHA"; \
    clonar wildminder/ComfyUI-Chatterbox         ComfyUI-Chatterbox           "$CHATTERBOX_SHA"; \
    for d in */; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "== requirements de $d"; \
        uv pip install -c /opt/candado-base.txt -r "$d/requirements.txt"; \
      fi; \
    done; \
    rm -rf */.git

COPY verificar-imagen.sh /opt/verificar-imagen.sh
RUN bash /opt/verificar-imagen.sh

WORKDIR /
