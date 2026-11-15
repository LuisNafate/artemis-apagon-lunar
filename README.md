# ARTEMIS · Última ventana

Entrenador de misión de gestión y supervivencia lunar para astronautas junior. Juega con un astronauta sin conexión o comparte la base con otra persona en línea. Reúne materiales, mantén las reservas y prepara el regreso a la Tierra. El progreso se guarda por base y por modo. Ambos modos comparten monedas y desbloqueos. Las nueve regiones y sus reglas proceden de la [especificación del 14 de noviembre](context_core/Artemis_Reglas_y_mecanicas.pdf).

## Jugar al corte actual

Windows ejecuta `Artemis-Ultima-Ventana.exe`. Desde Godot 4.7.2, abre `project.godot` y pulsa **F5**. Pulsa **Entrar al puesto lunar** en la portada.

- **Jugar solo · sin conexión.** Elige **Mons Mouton Plateau** y toma y entrega la muestra en la mesa azul. Puedes pausar desde el menú. El regreso a Tierra requiere tu asiento.
- **Crear partida en línea.** Elige una base y comparte la dirección que aparece. En el segundo dispositivo, escribe esa dirección y pulsa **Unirme en línea**. El prototipo usa conexión directa UDP 44260. En la misma red, ambos equipos deben alcanzar esa dirección. Para probar con dos procesos en el mismo equipo sin compartir el archivo del perfil, inicia el segundo con `Artemis-Ultima-Ventana.exe -- --perfil=invitado` y conéctalo a `127.0.0.1`.

Mueve tu piloto con el joystick de pantalla o toca un punto del suelo. **Acción** opera una estación cercana. **Soltar / pasar** entrega o deposita la caja. En Windows se puede usar el ratón para probar estos mismos controles.

En cooperativo, pasa la muestra a tu compañero para que la deposite. De día recarga la batería. De noche vuelve al refugio cuando baje el aire. **Menú → Guardar y salir** conserva el ciclo en individual o al alojar una partida. Al amanecer se guarda el avance y se acreditan las monedas.

Para regresar a Tierra, carga tres lotes de propelente y dos raciones, confirma por radio y ocupa los asientos del modo elegido. El módulo lunar asciende, se acopla en órbita y la nave de mando y servicio emprende el regreso. Después puedes seguir jugando en la base.

Para jugar en línea necesitas una dirección alcanzable. Las fichas científicas se leen localmente. Hay pilotos felinos, AstroCat y las adaptaciones de Apolo y LRO dentro del escenario. El relieve LOLA de Nobile y el entorno de cráteres son modelos de ambientación.

[Auditoría de terreno y cámara](context_core/auditoria_terreno_campana.md) · [Estado de las reglas y parámetros provisionales](context_core/campana_lunar_vigente.md) · [Catálogo para modelado](context_core/catalogo_produccion_artemis.md) · [Catálogo científico](context_core/science_catalog.md) · [Registro de modelos](assets/props_luna/asset-register.md)

## Android

Descarga `Artemis-Ultima-Ventana.apk` de la [demo Android en GitHub](https://github.com/LuisNafate/artemis-apagon-lunar/releases/tag/v1.0.0-android.1) y ábrelo en un teléfono Android 7.0 o posterior con ARM64. Es una compilación de prueba para instalación directa. Puedes elegir partida individual sin conexión o cooperativo por dirección IP. La firma y el manifiesto se verificaron con Android SDK Build-Tools. Está pendiente la prueba en un teléfono.

Para exportar desde Godot 4.7.2, instala las plantillas de esa versión, configura Java y el SDK y ejecuta `godot --headless --path . --export-debug Android dist/Artemis-Ultima-Ventana.apk`. [Guía de exportación de Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)

## Escenas históricas

Abre `crest/crest.tscn` y pulsa **F6** para revisar la demo anterior de Estación Cresta, juego local con teclado y su introducción. Su comportamiento sirve de referencia de desarrollo.

## Apagón lunar

Abre `field/field.tscn` y pulsa **F6**. En esta escena de desarrollo, restaura la red y recupera dos cápsulas de cultivo. Usa WASD o flechas, Espacio para saltar, Shift para el impulso, E para interactuar y R para reiniciar.

## Prototipo de tablero

Abre `outpost/outpost.tscn` y pulsa **F6**. Administra el puesto durante ocho turnos y protege a dos tripulantes mientras consigues dos cosechas.

- Pulsa **1** para soporte vital, **2** para cultivo y **3** para la ventilación del refugio. También puedes hacer clic en los módulos.
- Pulsa **E** para entrar al refugio. El cultivo se pausa durante la protección.
- Ensaya reparaciones o una derivación y compara las reservas proyectadas. **Espacio** confirma el turno.
- Pulsa **R** para reintentar y **Tab** para alternar entre las dos misiones. El resultado Oro pide terminar con exposición de 1 o menos y conservar una pieza.

Las reservas y la exposición se expresan en unidades de juego. El diseño, el alcance del reto, las fuentes y las comprobaciones están en [context_core/outpost_design.md](context_core/outpost_design.md).

## Prototipo de academia

Abre `src/mission.tscn` en el editor y pulsa **F6** para jugar la versión de recepción de tripulaciones.

- **Clic** en el mapa para caminar o en un módulo para acercarte. También puedes caminar con **WASD** o las flechas.
- **E** o el botón de la estación para operar al llegar.
- **Esc** para pausar o reanudar. **Reiniciar** vuelve al informe inicial y repone las reservas.

Activa el soporte vital y riega el cultivo. Cuando el regolito reduzca la generación, limpia los paneles. Una vez listo el cultivo, abre la esclusa, calibra la baliza exterior y regresa antes de agotar el oxígeno del traje. Mantén las reservas hasta que termine el turno.

## Academia y recepción

Elige **Practicar** para aprender en seis pasos con el reloj detenido. Empieza por operar soporte vital y cultivo. Después diagnostica una avería, construye un hábitat y recibe a dos cadetes. **Iniciar misión** salta la práctica.

Durante la misión, el panel indica cuándo llega cada grupo y cuántas camas quedan libres. Construye un hábitat junto a una pasarela y usa la estación **Recepción** para admitir a Alfa y Bravo. Las tripulaciones necesitan reservas y soporte vital. Bravo requiere además que el cultivo esté listo. Los visitantes ocupan camas y aumentan el consumo hasta su salida. Al partir dejan agua y materiales.

En el minuto 76 surge una avería. Ve a **Soporte vital**, elige un diagnóstico y reserva dos materiales para el filtro. Para ganar, completa la salida exterior, recupera los sistemas y atiende a las dos tripulaciones.

## Ampliar la base

Pulsa **B** o **Construir**. Coloca la primera **Pasarela** junto a una marca verde del borde y amplíala con clic o arrastre. Selecciona **Hábitat**, **Invernadero** o **Batería** y coloca el plano junto a una pasarela. El menú muestra el coste, el efecto y el tiempo de obra. **Esc** o clic derecho cierran el modo de construcción. Completa al menos un módulo para ganar el turno.

- **Hábitat** amplía la capacidad de oxígeno en 0.12 kg.
- **Invernadero** suma un punto de crecimiento por minuto con energía.
- **Batería** añade 0.40 kWh de capacidad.

El [análisis del SWF](context_core/resort_empire_analysis.md) documenta las funciones observadas de Resort Empire y sus equivalentes en Artemis.

## Validar

Desde la raíz del proyecto en PowerShell:

```powershell
python3 -m pip install --user gdtoolkit
./tests/verify.ps1
```

Si Godot está en otra ubicación, usa `./tests/verify.ps1 -Godot 'C:/ruta/Godot_console.exe'`. La verificación ejecuta formato, lint, importación, arranque de la escena y regresiones sin interfaz.

## Editar

El grafo, los parámetros del escenario y la auditoría están en `context_core/`. El motor lee `state_registry.json` al arrancar. Los sprites, las teselas y la iconografía originales se guardan en `assets/`. Para regenerarlos, instala Pillow y ejecuta `python3 tools/draw_assets.py`. Las fuentes Barlow, Barlow Condensed e IBM Plex Mono incluyen sus licencias OFL en `assets/ui/fonts/`.

El prototipo de academia usa un atlas de visitantes generado a partir del astronauta original de Artemis. Para regenerarlo, ejecuta `python3 tools/draw_field_visitors.py`. [Análisis histórico de Resort Empire](context_core/resort_empire_analysis.md)

El balance usa tasas de consumo humano de NASA y simplifica el soporte vital, la recuperación de agua, la generación solar y el consumo del traje para el ejercicio. El indicador de CO₂ muestra masa acumulada. [Tasas de referencia](https://ntrs.nasa.gov/api/citations/20160005782/downloads/20160005782.pdf) · [Sistemas ECLSS de NASA](https://www.nasa.gov/reference/environmental-control-and-life-support-systems-eclss/)

La demo utiliza Godot Engine. El paquete de Windows incluye los avisos del motor y de las fuentes. [Licencia de Godot](https://godotengine.org/license/)
