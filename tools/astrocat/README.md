# AstroCat

Gato astronauta 3D reconstruido a partir de la referencia adjunta. Mantiene el casco abierto, las orejas que lo atraviesan, el hocico atigrado y el traje crema con bandas naranjas. La estrella, los ojos, los bigotes, el panel, la huella, la mochila y la cola tienen geometría editable.

## Archivos

| Archivo | Contenido |
| --- | --- |
| AstroCat.blend | Blender 5.2.2. Piezas editables en colecciones, esqueleto, Actions, texturas empaquetadas y estudio con seis cámaras |
| [astrocat_guia.glb](../../assets/pilotos/astrocat_guia.glb) | glTF 2.0 con una malla skinnada, dos materiales, texturas embebidas y cinco clips |
| AstroCat.fbx | Malla, esqueleto y cinco tomas para herramientas que admiten FBX |
| textures/ | Base Color de cara y traje, atlas de roughness en G y metallic en B |
| renders/ | Frontal ortográfica, posterior, dos perfiles y dos vistas de tres cuartos |
| animations/ | Poses de referencia y resultados de reimportación de los cinco clips |
| scripts/ | Generación de texturas y mallas, rig, exportación, render y verificación |

El modelo tiene **9 428 triángulos y 20 huesos**. Pies al origen, Z arriba y frente hacia −Y en Blender. La altura de autoría es de aproximadamente 3,37 unidades. En Godot, copia AstroCat.glb a una carpeta importada del proyecto, instancia la escena y ajusta la escala del nodo padre. Conserva los transformados del esqueleto. El archivo .gdignore protege la carpeta de autoría en este repositorio. Artemis instancia la versión importada en el hábitat y reproduce Wave seguido de Idle. Las salidas FBX, renders y previsualizaciones se regeneran con los comandos de esta página.

## Editar y animar

Abre el archivo BLEND y selecciona **AstroCat_Rig**. En Dope Sheet → Action Editor, asigna una de las acciones. Todas están a 30 fps. La cola y el torso admiten deformación, los paneles de traje se mueven con su articulación y la cabeza mantiene sus piezas alineadas.

- **Idle** respira y balancea la cola.
- **Walk** y **Run** son ciclos en el sitio. La lógica del juego aporta el desplazamiento.
- **Jump** incluye anticipación, elevación y aterrizaje. Si el motor controla la altura física, ajusta el movimiento vertical del clip al integrarlo.
- **Wave** es un saludo corto con una pata.

Los colores y las marcas se pueden repintar en las UV de cara y del panel posterior. Las piezas auxiliares reutilizan celdas con margen del atlas. Las facetas provienen de la geometría y sus normales. Los materiales usan dos atlas de Base Color y un mapa combinado. No se requiere un mapa de normales.

## Reproducir

Ejecuta estos comandos desde la carpeta AstroCat, con Blender 5.2.2 y Pillow.

```powershell
python scripts/paint_textures.py
blender --background --factory-startup --python-exit-code 1 --python scripts/build_astrocat.py
blender --background --factory-startup --python-exit-code 1 --python scripts/verify_astrocat.py
blender --background AstroCat.blend --python-exit-code 1 --python scripts/preview_animations.py
```

Añade `-- --draft` para generar tres renders de baja resolución o `-- --skip-renders` para rehacer solo BLEND, GLB y FBX.

## Comprobaciones

Se corrigieron la estrella del casco, las proporciones de las orejas, el contraste de los ojos y las articulaciones tras revisar renders y poses. La referencia es una ilustración, por lo que la profundidad del casco, las superficies ocultas y la geometría de la mochila se reconstruyeron a partir de sus vistas laterales y posterior.

Se reimportaron el GLB y el FBX en Blender y se midió la deformación de las cinco acciones. Godot 4.7.2 importó el GLB con dos superficies texturizadas y reprodujo los cinco clips en un proyecto de prueba.
