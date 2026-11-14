# Artemis · Turno de tormenta

El resumen del reto **Entrenador de misión para astronautas junior** pide administrar un puesto lunar o marciano equilibrando soporte vital, radiación, energía y alimentos. La imagen del usuario se usa como resumen de alcance. La búsqueda oficial no devolvió una ficha específica de 2026, por lo que los criterios de esta iteración se basan en el resumen compartido.

## Hipótesis de juego

Cada turno plantea una situación legible. El jugador configura módulos y decide cuándo gastar piezas de reparación, después ve el resultado antes de confirmar. La red se divide en dos ramales y una derivación. El soporte recupera aire y agua, el cultivo necesita ciclos con energía y consume agua al cosechar, y refugiarse reduce exposición y pausa el cultivo. La batería recoge excedentes y cubre déficits. Los cortes futuros aparecen en el pronóstico. Un botón de simulación permite tomar riesgos sin esperar tiempo real.

La propuesta de rescate aporta una meta clara y reintento rápido. La de mantenimiento por estaciones aporta un puesto reconocible. La red táctica combina el objetivo del reto con decisiones que pueden cambiar el resultado. Las estaciones se representan como una vista cenital de consola lunar con señal de continuidad, instalaciones dibujadas y controles directos. Activa un módulo, consulta el pronóstico y confirma el turno.

## Comprobaciones

- Consistencia: la predicción y la resolución producen el mismo estado y previsualizar no gasta recursos. Una ruta estable y una ruta de emergencia deben poder ganar con decisiones distintas.
- Adversario: prueba decisiones automáticas de mantener todo activo, dejar cultivo apagado y permanecer fuera del refugio. Prueba un corte seguido de una reparación, una derivación y un presupuesto agotado.
- Regresión: inicio, escena normal, tutorial contextual, teclado y ratón, derrota explicada, reinicio y victoria. La diversión requiere una nueva prueba de usuario.

## Fuentes

- [NASA ECLSS](https://www.nasa.gov/reference/environmental-control-and-life-support-systems-eclss/) inspira la recuperación de aire y agua.
- [NASA Science](https://science.nasa.gov/science-research/heliophysics/how-nasa-will-protect-astronauts-from-space-radiation-at-the-moon/) inspira el pronóstico y la protección física.
- [Into the Breach](https://store.steampowered.com/app/590380/Into_The_Breach/) aporta el patrón de amenazas anunciadas antes de resolver.
- [Celeste](https://www.celestegame.com/changelog.html) aporta el patrón de reinicio inmediato.

Las cifras son unidades de juego. La exposición se expresa como puntos acumulados. La reducción de generación y el corte son incidentes independientes programados en el mismo guion.

## Motivación para repetir

La investigación de autodeterminación asocia la sensación de competencia y autonomía con el disfrute y la intención de volver. Se traduce a decisiones comparables en el mapa y retroalimentación directa sobre cada reserva. El estudio de CHI 2024 encontró que los efectos se benefician de resultados legibles y de grados de éxito. El sonido señala cosecha y resultado. La victoria de oro pide baja exposición y una pieza sobrante para distinguir un plan eficiente de uno que alcanza a sobrevivir.

- [Ryan, Rigby y Przybylski, The Motivational Pull of Video Games](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf)
- [Kao y colaboradores, How Does Juicy Game Feedback Motivate?](https://spiral.imperial.ac.uk/entities/publication/253c32f5-d124-4a23-88b5-9aaaf114608d)
