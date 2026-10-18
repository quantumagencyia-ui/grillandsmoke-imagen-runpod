# imagen-runpod — worker de RunPod de Grill & Smoke

`worker-comfyui` 5.10.0 (CUDA 12.8) + ComfyUI-WanVideoWrapper (InfiniteTalk y
Wan 2.2), KJNodes, VideoHelperSuite y ComfyUI-Chatterbox, fijados por commit.
Qwen-Image-Edit-2511 lo trae el ComfyUI de la base; el build lo comprueba.

- `Dockerfile` + `verificar-imagen.sh`: la imagen. El build arranca ComfyUI
  en CPU y falla si un nodo no carga o si un requirements movió torch.
- `.github/workflows/imagen.yml`: construye amd64 en cada push a `main` que
  toque la imagen y la sube a `ghcr.io/<dueño>/<repo>:sha-<commit>` y `:latest`.
- `modelos.txt` + `poblar-volumen.sh`: los ~91 GB de modelos, al network volume.

El endpoint se fija al tag `sha-…`, nunca a `latest`.
