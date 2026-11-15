# Campaña lunar · Reglas vigentes

**Especificación de referencia** · [Artemis · Última ventana, 2026-11-14](Artemis_Reglas_y_mecanicas.pdf). El objeto `campaign_2026` de [state_registry.json](state_registry.json) registra reglas, cifras y parámetros de integración. La revisión 15 incorpora la decisión del usuario de ofrecer también juego individual sin conexión y resuelve VAC-11. La demo de Cresta y sus catálogos de revisiones anteriores quedan como referencia histórica y repositorio de modelos.

## Trazabilidad de diseño

| Códigos | Alcance vigente |
| --- | --- |
| RES-1 a RES-7, JUG-1 a JUG-15, CTL-1 a CTL-13 | El menú del MVP abre una misión individual sin conexión. Controles táctiles, roles opcionales y guardado por base. |
| EST-1 a EST-13, BAS-1 a BAS-5 | Nueve regiones, dificultad fija, Mons Mouton Plateau inicial, desbloqueos libres por compra. La ficha de arte y geometría vive en [el catálogo de producción](catalogo_produccion_artemis.md). |
| TIE-1 a TIE-7, RET-1 a RET-5 | Día de 420 s, noche de 480 s, checkpoint y monedas al amanecer. Aire cero devuelve a ese punto y mantiene el perfil. |
| REC-A1 a REC-A6, REC-E1 a REC-E7, REC-W1 a REC-W5, REC-H1 a REC-H4, REC-1 a REC-5 | Consumo según dificultad, aire individual, hambre individual, blindaje independiente del soporte vital, cargas y recursos de producción. |
| ESC-1 a ESC-6, MEJ-1 a MEJ-7 | Cinco zonas y cuatro mejoras de mineral. Una única propiedad por caja y una instalación por mejora. |
| EVT-1 a EVT-12c | Advertencia de partículas, apagón nocturno, corte de radio solo en Nobile Rim 2. |
| MIS-1 a MIS-7, MON-1 a MON-12 | Regreso a Tierra, confirmación de 2,56 s, salida de 30 s cancelable, modo libre y bono único por base. Se requiere un asiento en individual y dos en cooperativo. |

## Individual sin conexión · VAC-11

En **Jugar solo** controlas a un astronauta. Recoges una muestra y la depositas en la mesa de práctica. La misión requiere tres lotes de propelente, dos raciones, radio y tu asiento. El menú pausa el tiempo y al amanecer recibes el 100 % de las monedas. **Continuar misión** abre la última base individual guardada.

Cada base guarda el avance individual y cooperativo en ranuras distintas. Las monedas, los desbloqueos y el registro del bono único por base pertenecen al mismo perfil. La portada indica **Campaña completada** al acreditar los regresos de las nueve bases. Después puedes seguir jugando.

## Regreso por órbita lunar

El objetivo sigue siendo volver a la Tierra. Al terminar la cuenta regresiva solo sale la etapa de ascenso del módulo lunar. La cinemática presenta el encuentro con la nave orbital, el viaje y la entrada de la cápsula de mando. El bono se confirma al terminar la secuencia. La [auditoría de terreno](auditoria_terreno_campana.md) documenta colocación, cámara y fuentes.

## Decisiones pendientes de diseño

- **REC-E7.** En Media, una noche usa 8 unidades de soporte vital y un cultivo usa 2. El total calculado es 10 de 12. La descripción cualitativa indica insuficiencia. Registrar ambos en las pruebas y usar las cifras explícitas hasta aclarar la fuente del consumo adicional.
- **VAC-1.** Para el código prevalecen TIE-1, TIE-4 y la tabla 17. Un ciclo completo cuenta al llegar al segundo amanecer.
- **VAC-3 y VAC-10.** Momento en que cambia el rol y efecto de pausa sobre la simulación en línea. El menú táctil da acceso a opciones sin asignar una pausa global.
- **VAC-8.** La retirada se activa al agotar el aire. El efecto de la exposición sigue pendiente.
- **VAC-16.** Los 14 s del cultivo y los 9 s del propelente son valores de prototipo reutilizados para comprobar el circuito. Deben cambiarse en el registro cuando se acuerden cifras. El montaje de una mejora usa 4 s de base para comprobar el bonus de ingeniería.
- **VAC-17.** Refuerzo solar tiene costo y arte especificados. El incremento de generación de día queda pendiente. La tabla de Haworth orienta su paisaje. Su curva de luz respecto a TIE-2 también requiere una decisión de diseño.
- **EVT-9.** La ventana usa provisionalmente 420–720 s, el mismo tramo en todos los ciclos de Nobile Rim 2. La duración de 300 s viene del PDF.
- **EVT-1 y EVT-4 · DONKI.** Cada alerta toma una llamarada real del [catálogo DONKI](data/donki_flares_v1.json). El aviso depende del tiempo real hasta las partículas: corto 10 s (menos de 1 h), medio 15 s (1 a 24 h) y largo 20 s (más de 24 h). Fácil usa avisos medios y largos (17,5 s de promedio); Media y Difícil, cortos y medios (12,5 s); Difícil solo llamaradas X. La alerta dura 25 s en lugar de 45 s. La frecuencia y el calendario de EVT-4 no cambian. Cada ciclo suma una falsa alarma de 8 s con una llamarada sin partículas, que no cuenta como alerta. Los mensajes usan palabras para niños de 7 a 12 años; un destello y el sonido «Sun Sonification» de la NASA (datos de SOHO, créditos en `assets/props_luna/nasa/procedencia.md`) marcan cada llamarada, suenan pitidos en los últimos 5 s del aviso, la cámara se sacude 0,6 s al llegar las partículas y la luz y los bordes de la pantalla se tiñen de rojo durante la alerta. Pendiente de aprobación del equipo; los valores viven en `campaign_2026.donki` y `campaign_2026.events.alert_seconds`.
- **VAC-18.** Mantener en diseño el árbol ramificado, módulos construibles, robots, personalización, eventos con elecciones, bitácora, álbum, minijuegos, gravedad, ayuda de mascota, lectura, dificultad adaptativa y descanso. AstroCat conserva su arte y animaciones.

## Referencias de producción

Los catálogos anteriores mantienen sus medidas históricas. Para nuevas piezas, usar [el catálogo vigente](catalogo_produccion_artemis.md). Las fuentes e instrumentos archivados en [science_catalog.md](science_catalog.md) y [lunar_reference_v1.json](data/lunar_reference_v1.json) conservan sus atribuciones.
