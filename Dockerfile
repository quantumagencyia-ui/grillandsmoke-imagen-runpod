# Imagen de RunPod serverless para Grill & Smoke: worker-comfyui + los nodos de
# InfiniteTalk y Wan 2.1 (WanVideoWrapper), Chatterbox (FL ChatterBox) y Qwen3-TTS
# (ComfyUI-Qwen-TTS), con el parche para que el worker devuelva audio y video y
# libere la RAM entre jobs. LTX-2.3 no necesita nodos: va en el núcleo de ComfyUI.
#
# Una sola base de video: Wan 2.1 I2V 14B 480p, que InfiniteTalk ya necesita,
# también para los close-ups de comida. Qwen-Image-Edit va por API externa.
#
# Los MODELOS NO VAN AQUÍ: viven en el network volume (/runpod-volume/models en
# serverless); ver modelos.txt y poblar-volumen.sh. Chatterbox también: el nodo
# los busca en /comfyui/models/chatterbox, que apunta al volumen.
#
# 5.11.0 tiene release en GitHub pero no imagen en Docker Hub (18-oct-2026).
ARG BASE=runpod/worker-comfyui:5.10.0-base-cuda12.8.1
FROM ${BASE}

# ComfyUI corre con el python del PATH (/opt/venv). La base trae además un
# /comfyui/.venv que no se usa; sin esto, uv lo descubre desde
# /comfyui/custom_nodes e instala ahí los requirements, lejos del runtime.
ENV VIRTUAL_ENV=/opt/venv

# Nodos fijados por commit: reconstruir tiene que dar la misma imagen.
ARG WANVIDEO_SHA=088128b224242e110d3906c6750e9a3a348a659b
ARG KJNODES_SHA=17195fcfa8a05f601b766a0f09c9733284f47416
ARG VHS_SHA=4d907bee61e92c2e65af3bd6383a4e4d356126d1
ARG CHATTERBOX_SHA=f7d7a16187430abcaf91a3039b9c83aa9960816a
ARG QWENTTS_SHA=a1328c8a731eff82cf4c205b31bdfb7f29d817f4

# Un nodo con un requirements suelto puede subir torch a una build cu13 que no
# arranca en los hosts de RunPod (driver 570/575). Se congelan las versiones que
# trae la base y se instalan los requirements contra ese candado.
RUN uv pip freeze | grep -iE '^(torch|torchvision|torchaudio|transformers|huggingface-hub)==' \
      > /opt/candado-base.txt \
    && cat /opt/candado-base.txt \
    && test "$(wc -l < /opt/candado-base.txt)" -eq 5
# `torch==2.11.0+cu128` no existe en PyPI (el 2.11.0 de PyPI es la build cu13),
# así que uv también mira el índice cu128 de PyTorch: ahí el candado se cumple
# con lo que ya está instalado y no baja nada.
ENV UV_EXTRA_INDEX_URL=https://download.pytorch.org/whl/cu128 \
    UV_INDEX_STRATEGY=unsafe-best-match

WORKDIR /comfyui/custom_nodes
RUN set -e; \
    clonar() { git clone -q "https://github.com/$1.git" "$2" && git -C "$2" checkout -q "$3"; }; \
    clonar kijai/ComfyUI-WanVideoWrapper         ComfyUI-WanVideoWrapper      "$WANVIDEO_SHA"; \
    clonar kijai/ComfyUI-KJNodes                 ComfyUI-KJNodes              "$KJNODES_SHA"; \
    clonar Kosinkadink/ComfyUI-VideoHelperSuite  ComfyUI-VideoHelperSuite     "$VHS_SHA"; \
    clonar filliptm/ComfyUI_Fill-ChatterBox      ComfyUI_Fill-ChatterBox      "$CHATTERBOX_SHA"; \
    for d in */; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "== requirements de $d"; \
        uv pip install -c /opt/candado-base.txt -r "$d/requirements.txt"; \
      fi; \
    done; \
    rm -rf */.git

# Qwen3-TTS (VoiceDesign y clonación), revisado el 18-oct-2026. Va aparte: su
# requirements.txt pide onnxruntime-openvino (no hace falta en GPU) y el paquete
# qwen-tts de PyPI fija transformers==4.57.3, que choca con Chatterbox. El nodo
# trae su propia copia de qwen_tts, que corre con el transformers 5 de la base.
RUN set -e; \
    git clone -q https://github.com/flybirdxx/ComfyUI-Qwen-TTS.git ComfyUI-Qwen-TTS; \
    git -C ComfyUI-Qwen-TTS checkout -q "$QWENTTS_SHA"; \
    rm -rf ComfyUI-Qwen-TTS/.git; \
    uv pip install -c /opt/candado-base.txt librosa soundfile accelerate einops tiktoken \
      sentencepiece sox onnxruntime safetensors "scipy>=1.11.0"

# El extra_model_paths.yaml de worker-comfyui 5.10.0 solo mapea checkpoints, clip,
# clip_vision, loras, vae, unet… del volumen: sin esto ComfyUI no ve
# diffusion_models/, text_encoders/ ni wav2vec2/ (prueba del 18-oct: «not in []»).
# latent_upscale_models: el upscaler ×2 de LTX-2.3. qwen-tts: los de Qwen3-TTS.
RUN printf '  diffusion_models: models/diffusion_models/\n  text_encoders: models/text_encoders/\n  wav2vec2: models/wav2vec2/\n  latent_upscale_models: models/latent_upscale_models/\n  qwen-tts: models/qwen-tts/\n' \
      >> /comfyui/extra_model_paths.yaml \
    && cat /comfyui/extra_model_paths.yaml

# Pesos de Chatterbox en el volumen (models/chatterbox/chatterbox_multilingual).
RUN rm -rf /comfyui/models/chatterbox \
    && ln -s /runpod-volume/models/chatterbox /comfyui/models/chatterbox
# Qwen3-TTS busca en models/qwen-tts/<repo>/ (y guarda ahí sus voces).
RUN rm -rf /comfyui/models/qwen-tts \
    && ln -s /runpod-volume/models/qwen-tts /comfyui/models/qwen-tts

# worker-comfyui solo devuelve salidas bajo «images»: que devuelva audio y video.
# Y antes de cada job pide a ComfyUI que suelte los modelos del anterior: la 4090
# de serverless tiene 42.8 GB de RAM y dos Wan seguidos en el mismo worker la
# llenaban (OOM, 19-oct-2026). GS_LIBERAR_ENTRE_JOBS=false lo apaga.
COPY parchear_handler.py /opt/parchear_handler.py
RUN python3 /opt/parchear_handler.py /handler.py

COPY verificar-imagen.sh /opt/verificar-imagen.sh
RUN bash /opt/verificar-imagen.sh

WORKDIR /
