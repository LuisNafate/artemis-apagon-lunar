# Auditoría de terreno, cámara y regreso lunar

## Alcance

Se revisó la escena de campaña `lunar/lunar.tscn`. Hay nueve variantes regionales. Comparten las estaciones y la malla transitable, y cambian el suelo, el relieve perimetral y el perfil de cielo. Mons Mouton Plateau es la base inicial y el escenario de las pruebas de movimiento completo. El catálogo regional sigue siendo el punto de partida para crear terrenos con pendientes y rutas propias.

El plano que sigue usa unidades de juego en metros. X aumenta hacia la plataforma y Z hacia el borde cercano al jugador. El piso transitable está a Y = 0. La cámara ortográfica mira hacia la base con una elevación de 34°. El diseño original usaba aproximadamente 45,5°.

## Puntos de operación

| Elemento | X, Z (m) | Comprobación |
| --- | --- | --- |
| Inicio azul y naranja | −1,00/6,10 y 1,00/6,10 | Ambos puntos caen dentro del refugio y sobre el mismo piso físico. |
| Mesa de práctica | 0,00/5,30 | Se alcanza desde los dos inicios. El tutorial individual y el intercambio cooperativo depositan aquí. |
| Refugio | 0,00/2,90 | Dentro de la zona segura. Se mantuvieron la entrada central y los accesos laterales. |
| Hielo y mineral | −11,10/−0,50 y −11,10/4,20 | Cada depósito sólido está detrás de su punto de extracción. Su frente queda navegable. |
| Refinado y taladro | −5,10/−3,40 y −5,50/5,80 | Los puntos quedan delante del equipo y separados por dos rutas principales. |
| Red solar y refuerzo | 0,00/−5,10 y 4,88/−5,95 | Ambos se alcanzan desde los inicios. Comparten el mismo criterio de proximidad en el anfitrión y el invitado. |
| Cultivos y riego | 3,10/−2,20 y 3,14/0,65 | Las bancadas y el control de riego tienen puntos independientes. |
| Batería | 4,70/6,30 | Se desplazó su proyección dentro del encuadre al elevar la composición de juego. |
| Propelente y radio | 6,70/−2,40 y 6,30/3,90 | El frente de las consolas queda libre para interactuar. |
| Plataforma y embarque | 11,20/0,70 | El punto de operación y los dos asientos quedan delante del módulo lunar. El modelo se centra en 11,10/−2,90. |

La cubierta de juego mide aproximadamente 30,9 × 17,4 m. El límite físico tiene colisión en los cuatro lados. Los cráteres de borde quedaron fuera de la superficie caminable, incluida su envolvente. La pasarela y el suelo comparten cota de uso; las placas elevan unas centésimas su cara visible. En los cruces se separó la profundidad de las capas de renderizado para reducir el parpadeo. Se conservan las huellas de los objetos y las posiciones de los guardados.

## Fallos encontrados y correcciones

| Hallazgo | Corrección y verificación |
| --- | --- |
| La malla de piso se veía 1 cm debajo de la colisión. Varios tramos de pasarela se solapaban coplanares. | Piso de campaña en Y = 0. Separación submilimétrica entre capas de pasarelas. Rayos en los 14 puntos de operación y los dos inicios confirman el nivel físico. |
| Las figuras de la cantera y algunas consolas eran atravesables. El sondeo de rutas usaba rayos laterales de 0,26 m frente a un piloto de radio 0,32 m. | Se añadieron volúmenes sencillos detrás de los puntos de acceso y una sonda de cápsula de 0,38 m en la cuadrícula de 0,50 m. El margen incluye la holgura de manejo del mando táctil. |
| Varios cráteres rozaban el límite y se veía una barra atravesando uno de ellos. | Desplazados al exterior. Se comprobó la envolvente de los seis cráteres en cada base. |
| El horizonte del bloque de suelo tenía un corte recto y dejaba poco espacio para el cielo. | Faldón de suelo con borde irregular y crestas por región. El HUD ocupa la esquina superior izquierda y deja libre el cielo a la derecha. |
| La cápsula de la plataforma y el Apolo estacionado sugerían dos vehículos lunares simultáneos. | El modelo Apolo se integra en la plataforma. La etapa de descenso se queda en la superficie y la superior sale en la cinemática. |

La prueba navegó desde ambos puntos de inicio a los 14 anclajes. El mayor camino calculado desde esos puntos hacia el refugio fue de **14,95 m**. Una prueba independiente condujo al piloto por la ruta del hielo hasta entrar en la zona protegida en **2,25 s de simulación**. La suite comprobó la proyección de las estaciones en la cámara y repitió los tutoriales y la partida en red. El análisis se limita al escenario compartido y sus variaciones. Los tiempos dependen del controlador y de la ruta en juego.

## Horizonte por base

- **Tierra visible** en Mons Mouton Plateau, Slater Plain, Malapert Massif, Mons Mouton y Nobile Rim 1.
- **Tierra intermitente** en Nobile Rim 2 durante el ciclo de pérdida de señal.
- **Espacio y crestas** en Peak near Cabeus B, de Gerlache Rim 2 y Haworth.

Estas son condiciones de composición. La escala aparente de la Tierra se amplía y la pérdida visual de Nobile Rim 2 acompaña el ciclo didáctico de radio existente. Para una simulación geográfica harían falta fecha, coordenadas y una prueba de obstrucción desde el punto de vista elegido. [NASA · Análisis de visibilidad del terreno de las regiones Artemis](https://ntrs.nasa.gov/api/citations/20250009664/downloads/CMS_Abstract_LSIC2025.pdf)

## Regreso e interfaz

La misión conserva la preparación de propelente, raciones, radio y asientos. Tras la cuenta regresiva muestra **ascenso**, **acoplamiento en órbita lunar**, **viaje hacia la Tierra** y **separación de la cápsula de mando antes de la entrada**. El bono se asegura al terminar el regreso. La secuencia dura 17 segundos en la simulación del juego, durante los cuales el turno de superficie se detiene. La nave orbital es una representación simplificada del módulo de mando y servicio. [NASA · Arquitectura del programa Apolo](https://www.nasa.gov/the-apollo-program/) · [NASA Technical Reports Server · Encuentro en órbita lunar](https://ntrs.nasa.gov/citations/20070030988)

La portada usa la escena 3D y un desplazamiento lento de cámara. La carga aparece al seleccionar o continuar una base mientras se prepara el mapa de rutas y se recupera el guardado. El HUD usa fichas cálidas de estado, un botón de acción verde y tarjetas de aviso. Los controles conservan al menos 50 px en la composición base. En vuelo, la tarjeta indica la etapa y la acción en curso y deja la escena libre de controles de superficie.

La Tierra usa la fotografía AS17-148-22727 de Apolo 17. [NASA Johnson Space Center · The Blue Marble](https://science.nasa.gov/resource/the-blue-marble/)
