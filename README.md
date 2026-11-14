# ARTEMIS · Última ventana

Entrenador de misión para astronautas junior. Juega en tres bases lunares 2.5D. Cresta enseña a sostener la base, Nobile añade cortes de radio y Taurus-Littrow añade averías de energía. Mantén a dos astronautas con vida, construye mejoras y prepara su ascenso a órbita lunar.

## Jugar

En Windows ejecuta `Artemis-Ultima-Ventana.exe` de la demo. Para editarla, abre `project.godot` con Godot 4.7.2 y pulsa **F5**. El menú permite elegir un jugador o dos jugadores locales sin conexión. Luego elige base y abre su historia animada. Esc omite la historia y deja el tutorial disponible.

| Modo | Movimiento | Actuar | Pasar o soltar |
| --- | --- | --- | --- |
| Un jugador | WASD, Tab cambia de astronauta | E | Q |
| Dos jugadores, J1 | WASD | E | Q |
| Dos jugadores, J2 | Flechas | Intro | Mayús derecha o / |

**Esc** pausa. **F1** abre el archivo científico. En el menú de pausa o en el informe, usa **R** para empezar de nuevo.

Los días y noches se aceleran para la misión. Usa las horas de luz para acumular energía y mira el aviso verde cuando llegue un suministro. El tutorial enseña a recoger y entregar una caja. En la misión, lleva hielo y mineral al refinado. Intercambia agua por aire, cosechas y lotes de propelente. Puedes invertir el mineral en un taladro más rápido o en una batería que te ayude durante el apagón. Para despegar, carga tres lotes y dos raciones, confirma la lista con Tierra y sienta a ambos astronautas.

Las muestras históricas de NASA DONKI, RadLab y NeoWs, junto con un TLE terrestre de la ISS, funcionan sin Internet. Las magnitudes didácticas y la procedencia se explican en el [catálogo científico](context_core/science_catalog.md). El [diseño de Estación Cresta](context_core/coop_tycoon_design.md) describe los calendarios y las bases. El [registro de modelos](assets/props_luna/asset-register.md) identifica los objetos CC0 de Kenney.

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
