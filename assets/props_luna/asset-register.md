
# Modelos lunares reutilizables

| Modelo | Autor y licencia | Archivo | Uso y ajuste |
| --- | --- | --- | --- |
| [Mining Spacecraft](https://poly.pizza/m/wJQEGUHttY) | Kenney · CC0 1.0 | kenney/transporte.glb | Transporte de la introducción anterior. Disponible como recurso de reserva |
| [Satellite Dish](https://poly.pizza/m/IDRrztoAMB) | Kenney · CC0 1.0 | kenney/antena.glb | Antena de las bases. Escala, posición y montaje animado |
| [Wireless Machine](https://poly.pizza/m/OJffxxkMtZ) | Kenney · CC0 1.0 | kenney/consola.glb | Receptor de radio. Escala, posición y montaje animado |

Los tres modelos se importaron en Godot 4.7.2 y comparten el escenario 2.5D y la iluminación de las bases. Las estaciones principales, el cohete de ascenso y el traje usan arte original. El módulo de descenso, la miniatura LRO y el recorte de Nobile se documentan en [modelos NASA](nasa/procedencia.md).

[Space Station Kit de Kenney](https://kenney.nl/assets/space-station-kit) y [Ultimate Space Kit de Quaternius](https://quaternius.com/packs/ultimatespacekit.html) son referencias CC0 para buscar piezas futuras. La colección [Space Kit de Kenney en Poly Pizza](https://poly.pizza/l/M8xXmqhHiU) contiene las fichas individuales de los modelos incorporados.

## Tripulación y terreno

- [Gato piloto](../pilotos/gato-modelo2.glb). Recurso del proyecto recuperado y adaptado con esqueleto de 15 huesos, malla de 11 384 triángulos y shader por astronauta. El script de articulación está en [tools/articulate_cat.mjs](../../tools/articulate_cat.mjs).
- [AstroCat](../pilotos/astrocat_guia.glb). Reconstrucción para el proyecto a partir de su referencia visual. Usa 9 428 triángulos, 20 huesos y cinco clips. El [archivo editable y sus comandos](../../tools/astrocat/README.md) se guardan con la autoría.
- [Cráteres de borde](../../crest/lunar_crater.gd). Seis modelos procedurales de 99 triángulos cada uno. Los anillos facetados, la pared sombreada y la variación de boca corresponden a la referencia del usuario.
