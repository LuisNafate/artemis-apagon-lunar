
# Modelos NASA adaptados para Artemis

Uso educativo. Las adaptaciones se acreditan a sus autores y a NASA. Los materiales del juego se prepararon sin las texturas o insignias de origen. Los modelos se incluyen localmente para que la partida y el archivo científico funcionen sin conexión. [Pautas de uso de NASA](https://www.nasa.gov/nasa-brand-center/images-and-media/)

| Archivo | Origen y crédito | Adaptación y uso |
| --- | --- | --- |
| `apollo_descenso.glb` | [Apollo Lunar Module](https://science.nasa.gov/3d-resources/apollo-lunar-module/) · NASA/Michael D. Carbajal | **97 588 → 8 472 triángulos**. Se simplificaron las mallas, se consolidaron cuatro materiales, se colocó el origen al suelo y se ajustó la dimensión máxima a 4,5 m. Cresta lo usa para un descenso ficticio inspirado en Apolo. La campaña usa sus dos etapas separadas en la plataforma. |
| `lro_miniatura.glb` | [Lunar Reconnaissance Orbiter (B)](https://science.nasa.gov/3d-resources/lunar-reconnaissance-orbiter-b/) · NASA/Brian E. Kumanchik y NASA/Christian A. Lopez | **8 142 → 1 701 triángulos**. Se simplificó la geometría, se unificaron cuatro materiales y se centró la malla. Gira dentro de la ficha de LRO del archivo científico de Cresta y en un pedestal de la campaña. Los datos sobre la misión proceden de [LRO Science and Data](https://science.nasa.gov/mission/lro/science-and-data/). |
| `relieve_nobile_lola.glb` | [NASA GSFC/PGDA · Site06, Nobile Rim 1](https://pgda.gsfc.nasa.gov/products/78) · Lunar Orbiter Laser Altimeter, LRO | **825 vértices y 1 536 triángulos**. Recorte de elevación, remuestreo, ajuste vertical y transición suavizada al piso. Se usa a modo de paisaje en el perímetro de los escenarios de Nobile, fuera del suelo físico. |

| `apollo_base_lunar.glb` y `apollo_etapa_ascenso.glb` | Derivados del Apollo Lunar Module citado arriba | 3 438 y 5 240 triángulos. Corte vertical de presentación por el plano horizontal Y = 1,56 en Godot, con origen común. La base permanece en el área de descenso. |
| `tierra_apolo17.jpg` | [NASA JSC · AS17-148-22727](https://science.nasa.gov/resource/the-blue-marble/) | Copia de 540 × 540 de NASA EOL. La fotografía de Apolo 17 se compone por mezcla aditiva sobre el cielo de la campaña. |
| `assets/cinematica/modelos/luna_lro.glb` | [Moon 3D Models for Web, AR, and Animation](https://svs.gsfc.nasa.gov/14959/) · NASA's Goddard Space Flight Center (producción: Dan Gallagher; datos: Ernie Wright; análisis: Tuomas Kankola y Josh Klint) | Variante con cuadrícula `Moon_NASA_LRO_15k_Grid_Small.glb`. Se borraron las líneas de latitud y longitud de la textura por interpolación y se redujo de 15 000×7 500 a 6 144×3 072 px. Solo se usa en la película de inicio (Blender). |

La nave orbital de la cinemática usa geometría creada en Godot. Simplifica la silueta del módulo de mando y servicio. [NASA · Programa Apolo](https://www.nasa.gov/the-apollo-program/)

## Sonido de las llamaradas

| Archivo | Origen y crédito | Adaptación y uso |
| --- | --- | --- |
| `sol_sonificacion_soho.ogg` | [NASA · Sounds of the Sun](https://www.nasa.gov/solar-system/sounds-of-the-sun/), pista «Sun Sonification» · A. Kosovichev, Stanford Experimental Physics Lab. Sonificación de 40 días de datos del instrumento MDI de SOHO (ESA/NASA), acelerados 42 000 veces para que se puedan oír. | Tramo de 7 s (de 54,5 s a 61,5 s de 82,8 s), mono a 22 050 Hz, entrada de 0,5 s, salida de 2 s y volumen normalizado. Sin cambio de tono, para conservar el dato. Suena en la campaña cuando aparece cada llamarada, junto con el destello. La página no indica licencia; se usa con fines educativos y con este crédito. |
| `sol_sonificacion_soho_bucle.ogg` | Mismo original y mismo crédito. | Bucle de 16 s (de 50 s a 68 s, con los últimos 2 s fundidos sobre los primeros para empalmar sin corte), mono a 22 050 Hz y al mismo volumen que el tramo corto. Sin cambio de tono. Suena sin pausa desde que se anuncia una tormenta hasta que termina la parte roja; se apaga en 1,5 s al terminar o al abrir un menú. Las falsas alarmas usan el tramo corto. |

Original: [sun_sonification.wav](https://www.nasa.gov/wp-content/uploads/2018/07/sun_sonification.wav) · SHA-256 `c2299c81ef4132c314b5a13e44af9fa6f8a4c4e733a2658df038291749f95bf8`

```bash
ffmpeg -ss 54.5 -t 7 -i sun_sonification.wav -ac 1 -ar 22050 -af "afade=t=in:st=0:d=0.5,afade=t=out:st=5:d=2,loudnorm=I=-16:TP=-1.5:LRA=7" -c:a libvorbis -q:a 5 assets/props_luna/nasa/sol_sonificacion_soho.ogg

python3 - <<'PY2'
import wave, numpy as np
w = wave.open("sun_sonification.wav"); sr = w.getframerate()
x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).reshape(-1, 2).mean(axis=1)
seg = x[50 * sr:68 * sr]; X = 2 * sr; fade = np.linspace(0, 1, X)
loop = seg[:-X].copy(); loop[:X] = seg[-X:] * (1 - fade) + seg[:X] * fade
o = wave.open("bucle.wav", "wb"); o.setnchannels(1); o.setsampwidth(2); o.setframerate(sr)
o.writeframes(np.clip(loop, -32768, 32767).astype(np.int16).tobytes()); o.close()
PY2
ffmpeg -i bucle.wav -ar 22050 -af "volume=-7.8dB,alimiter=limit=0.84" -c:a libvorbis -q:a 5 assets/props_luna/nasa/sol_sonificacion_soho_bucle.ogg
```

## Reproducir los GLB

Guarda las descargas originales con estos nombres en un directorio temporal.

| Entrada | Descarga original | SHA-256 |
| --- | --- | --- |
| `apollo-lunar-module.glb` | [GLB NASA](https://assets.science.nasa.gov/content/dam/science/cds/3d/resources/model/apollo-lunar-module/Apollo%20Lunar%20Module.glb) | `379101dfcee399267addf771709107c35e826b0b9e5233272f123e4c8a585c4e` |
| `lunar-reconnaissance-orbiter-b.glb` | [GLB NASA](https://assets.science.nasa.gov/content/dam/science/cds/3d/resources/model/lunar-reconnaissance-orbiter-%28b%29/Lunar%20Reconnaissance%20Orbiter%20%28B%29.glb) | `c868a65e36ed293476be3d05e7e60968778c5cf4b2a7aba8859fcc20242a0612` |
| `nobile-site06.tif` | [GeoTIFF Site06 LDEM, 5 m/píxel](https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/Site06/Site06_final_adj_5mpp_surf.tif) | `cca17e8067601dd659b583f889204db6bce685bc30c60a9e62427a8bce36b03d` |

```powershell
blender -b --python-exit-code 5 --python tools/optimizar_modelos_nasa.py -- CARPETA_ORIGINALES assets/props_luna/nasa
blender -b --python tools/separar_modulo_apolo.py -- assets/props_luna/nasa
python tools/generar_relieve_nobile.py CARPETA_ORIGINALES/nobile-site06.tif assets/props_luna/nasa/relieve_nobile_lola.glb
```

Verificado con Blender 5.2.2 y Pillow 12.3.0. El rectángulo fuente de Nobile ocupa las columnas 2150–2789 y filas 1450–1929 de Site06. En las coordenadas estereográficas del producto, abarca de X 84 750 a 87 950 m y de Y 110 350 a 112 750 m. Se remuestreó de **640 × 480** a **33 × 25**. El prototipo gira el recorte, comprime el plano y normaliza su altura para encuadrarlo. Las rutas, posiciones de módulos y ventanas de radio continúan siendo parámetros del juego.
