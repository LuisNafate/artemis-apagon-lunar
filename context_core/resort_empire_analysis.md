# Resort Empire y la ampliación de Artemis

Se analizó el binario `resort-empire.swf` proporcionado para esta revisión. Identificador SHA-256 `AD57F54FD897BEDEB36F45C484A00671678E1C5A111A35A19529C6D51C71D61D`. FFDec 26.4.0 exportó 496 archivos ActionScript para inspección estática. La implementación de Artemis usa GDScript y arte originales.

| Comportamiento observado | Evidencia en el SWF | Adaptación en Artemis |
| --- | --- | --- |
| La huella visual cambia según el terreno. | `TemporaryObject.groundAnim` y `Application.CheckTempObjectVal` distinguen la posición válida y comprueban las celdas. | El plano se superpone al mapa. El menú explica conexión, límite, ocupación o coste. |
| Confirmar la pieza verifica fondos. Las teselas se pueden pintar con el botón presionado. | `Application.ClickContainer` valida la compra. `Application.OnDrawTile` procesa el arrastre sobre teselas válidas. | Las pasarelas se pintan con clic y arrastre. El coste se cobra por huella aceptada. |
| Las rutas conectan instalaciones con teselas transitables. | `MapContainer.updateTilesPath_all` propaga cambios de ruta. `Application.CheckRoomWithPath` consulta conectividad para su objetivo. | Una pieza requiere pasarela conectada desde la plataforma. Las rutas del astronauta incluyen las pasarelas nuevas. |
| Las instalaciones pasan de obra a servicio. | `Booth.buildFunction` y `Booth.endBuildAnimasi` gestionan la transición al terminar la obra. | La huella queda reservada desde la colocación. La capacidad adicional o la mejora de cultivo empieza al completarse. |
| El área y el catálogo progresan mediante compras y desbloqueos. | `Application.acceptPurchaseExpand` y `MapContainer.acceptExpanding` muestran el flujo de ampliación. | El ejercicio incluye un sector de ampliación y un catálogo de cuatro piezas. |

El SWF comprueba la ruta por separado de la huella. Artemis exige una pasarela conectada al confirmar para que toda obra entre en servicio al completarse. La economía usa materiales de montaje. El hábitat y la batería añaden capacidad vacía. El invernadero acelera el progreso mientras el cultivo recibe energía.

[Publicación del autor](https://www.newgrounds.com/portal/view/613403) · [Página de Little Giant World](https://www.littlegiantworld.com/games/resort-empire/)

## Visitantes y atlas de personajes

`pack.Instance.Visitor.gerakArah` usa el estado de movimiento y los signos de los ejes para elegir poses frontales y traseras. Invierte el eje horizontal para obtener cuatro direcciones. `roomCategoryTersedia_path`, `startEntering0Room` y `insideRoomActivity_tick` distinguen disponibilidad con ruta, entrada y estancia. Artemis aplica ese patrón a recepción, camas y partida.

La revisión 5 ensayó una adaptación del símbolo `Visitor1` (2259, Little Giant World). Esa prueba se archivó fuera del proyecto. En la revisión 7, `assets/sprites_25d/visitors.png` se genera desde el astronauta original de Artemis mediante `python3 tools/draw_field_visitors.py`. La prueba de arte del SWF quedó como referencia de estudio.
