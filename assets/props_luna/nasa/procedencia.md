
# Modelos NASA adaptados para Artemis

Uso educativo. Las adaptaciones se acreditan a sus autores y a NASA. Los materiales del juego se prepararon sin las texturas o insignias de origen. Los modelos se incluyen localmente para que la partida y el archivo científico funcionen sin conexión. [Pautas de uso de NASA](https://www.nasa.gov/nasa-brand-center/images-and-media/)

| Archivo | Origen y crédito | Adaptación y uso |
| --- | --- | --- |
| `apollo_descenso.glb` | [Apollo Lunar Module](https://science.nasa.gov/3d-resources/apollo-lunar-module/) · NASA/Michael D. Carbajal | **97 588 → 8 472 triángulos**. Se simplificaron las mallas, se consolidaron cuatro materiales, se colocó el origen al suelo y se ajustó la dimensión máxima a 4,5 m. La introducción lo usa para un descenso ficticio inspirado en Apolo. |
| `lro_miniatura.glb` | [Lunar Reconnaissance Orbiter (B)](https://science.nasa.gov/3d-resources/lunar-reconnaissance-orbiter-b/) · NASA/Brian E. Kumanchik y NASA/Christian A. Lopez | **8 142 → 1 701 triángulos**. Se simplificó la geometría, se unificaron cuatro materiales y se centró la malla. Gira dentro de la ficha de LRO del archivo científico. Los datos sobre la misión proceden de [LRO Science and Data](https://science.nasa.gov/mission/lro/science-and-data/). |
| `relieve_nobile_lola.glb` | [NASA GSFC/PGDA · Site06, Nobile Rim 1](https://pgda.gsfc.nasa.gov/products/78) · Lunar Orbiter Laser Altimeter, LRO | **825 vértices y 1 536 triángulos**. Recorte de elevación, remuestreo, ajuste vertical y transición suavizada al piso. Se usa a modo de paisaje en el perímetro de Puesto Nobile, fuera del suelo físico. |

## Reproducir los GLB

Guarda las descargas originales con estos nombres en un directorio temporal.

| Entrada | Descarga original | SHA-256 |
| --- | --- | --- |
| `apollo-lunar-module.glb` | [GLB NASA](https://assets.science.nasa.gov/content/dam/science/cds/3d/resources/model/apollo-lunar-module/Apollo%20Lunar%20Module.glb) | `379101dfcee399267addf771709107c35e826b0b9e5233272f123e4c8a585c4e` |
| `lunar-reconnaissance-orbiter-b.glb` | [GLB NASA](https://assets.science.nasa.gov/content/dam/science/cds/3d/resources/model/lunar-reconnaissance-orbiter-%28b%29/Lunar%20Reconnaissance%20Orbiter%20%28B%29.glb) | `c868a65e36ed293476be3d05e7e60968778c5cf4b2a7aba8859fcc20242a0612` |
| `nobile-site06.tif` | [GeoTIFF Site06 LDEM, 5 m/píxel](https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/Site06/Site06_final_adj_5mpp_surf.tif) | `cca17e8067601dd659b583f889204db6bce685bc30c60a9e62427a8bce36b03d` |

```powershell
blender -b --python-exit-code 5 --python tools/optimizar_modelos_nasa.py -- CARPETA_ORIGINALES assets/props_luna/nasa
python tools/generar_relieve_nobile.py CARPETA_ORIGINALES/nobile-site06.tif assets/props_luna/nasa/relieve_nobile_lola.glb
```

Verificado con Blender 5.2.2 y Pillow 12.3.0. El rectángulo fuente de Nobile ocupa las columnas 2150–2789 y filas 1450–1929 de Site06. En las coordenadas estereográficas del producto, abarca de X 84 750 a 87 950 m y de Y 110 350 a 112 750 m. Se remuestreó de **640 × 480** a **33 × 25**. El prototipo gira el recorte, comprime el plano y normaliza su altura para encuadrarlo. Las rutas, posiciones de módulos y ventanas de radio continúan siendo parámetros del juego.
