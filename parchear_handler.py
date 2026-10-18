"""Hace que worker-comfyui 5.11 devuelva audio y video además de imágenes.

El handler solo recoge `node_output["images"]`; SaveAudio deja su archivo en
`audio` y VHS_VideoCombine en `gifs`, y el handler los tira con un aviso.
Este parche recorre esas claves con el mismo código (base64 o S3).

Cada reemplazo debe aparecer exactamente una vez: si otra versión del
handler cambió el código, el build falla aquí en vez de devolver vacío.
"""
import sys
from pathlib import Path

CAMBIOS = [
    ('            if "images" in node_output:\n',
     '            for _clave in [c for c in ("images", "audio", "gifs", "videos") if c in node_output]:\n'),
    ("""{len(node_output['images'])} image(s)""",
     """{len(node_output[_clave])} archivo(s) en {_clave}"""),
    ('                for image_info in node_output["images"]:\n',
     '                for image_info in node_output[_clave]:\n'),
    ('            other_keys = [k for k in node_output.keys() if k != "images"]\n',
     '            other_keys = [k for k in node_output.keys()\n'
     '                          if k not in ("images", "audio", "gifs", "videos")]\n'),
]

ruta = Path(sys.argv[1])
codigo = ruta.read_text()
for viejo, nuevo in CAMBIOS:
    n = codigo.count(viejo)
    if n != 1:
        sys.exit(f"parche: esperaba 1 vez y encontré {n}: {viejo.strip()}")
    codigo = codigo.replace(viejo, nuevo)
ruta.write_text(codigo)
print("parche aplicado: el handler devuelve images, audio, gifs y videos")
