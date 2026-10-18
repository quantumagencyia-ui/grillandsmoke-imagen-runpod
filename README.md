# imagen-runpod — worker de RunPod de Grill & Smoke

`worker-comfyui` 5.10.0 (CUDA 12.8) + ComfyUI-WanVideoWrapper (InfiniteTalk y
Wan 2.1 I2V), KJNodes, VideoHelperSuite y FL ChatterBox, fijados por commit.
Es la **única** imagen del proyecto.

- `Dockerfile` + `verificar-imagen.sh`: la imagen. El build arranca ComfyUI
  en CPU y falla si un nodo no carga, si un requirements movió torch o si el
  handler no quedó parchado.
- `parchear_handler.py`: worker-comfyui solo devuelve las salidas bajo
  `images`, y el audio de `SaveAudio` y el video de `VHS_VideoCombine` llegan
  bajo `audio` y `gifs`. El parche hace que se devuelvan también. Si otra
  versión del handler cambia ese código, el build falla en vez de devolver
  vacío.
- `.github/workflows/imagen.yml`: construye amd64 en cada push a `main` que
  toque la imagen y la sube a `ghcr.io/<dueño>/<repo>:sha-<commit>` y `:latest`.
- `modelos.txt` + `poblar-volumen.sh`: los modelos, al network volume.

El endpoint se fija al tag `sha-…`, nunca a `latest`.

La imagen se construye en x86_64 (GitHub Actions), nunca en quantum-01.

## Endpoint

| ajuste | valor |
|---|---|
| GPU | la que salga de la tabla de costos aprobada |
| active workers | **0** (sin esto se cobra 24/7) |
| max workers | 1 |
| idle timeout | 5 s (= `RUNPOD_IDLE_S`) |
| execution timeout | 600 s (cada job además manda el suyo) |
| FlashBoot | sí |
| network volume | el de `modelos.txt`, en el mismo datacenter que la GPU |

Del endpoint salen `RUNPOD_ENDPOINT_ID`, `RUNPOD_GPU` y `RUNPOD_USD_POR_S`;
del volumen, `RUNPOD_VOLUMEN_GB` y `RUNPOD_USD_GB_MES`. Todo va al `.env`, y
el freno de `scripts/costos.py` suma jobs y volumen contra `BUDGET_USD_MES`.

## Orden de pruebas

1. **Una línea de Chatterbox:**
   `python3 scripts/voz.py guiones/2026-10-16_cuando-ponerle-sal-a-la-carne.json --tomas 3`.
   Hay que comprobar que termina `COMPLETED`, que el renglón de `costos.csv`
   cuadra con la factura y cómo suena.
2. **Un plano de InfiniteTalk** con la imagen del norteño. Es lo más riesgoso,
   porque el personaje es cartoon.
3. **Un clip de comida con Wan 2.1 I2V.**

## Lo que solo se confirma en la prueba

- Que el nodo acepte el idioma `Spanish (es)`. Si no, ComfyUI rechaza el
  workflow y el error trae las opciones válidas.
- Que la muestra `.wav` subida por `images` llegue a `LoadAudio` (el handler la
  sube por `/upload/image`).
