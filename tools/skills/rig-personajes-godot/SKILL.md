---
name: rig-personajes-godot
description: Prepara y verifica articulaciones y animaciones para personajes 3D en Godot. Úsala para sustituir modelos jugables, importar GLB con esqueleto o riggear mallas estáticas conservando controles y puntos de acople.
---

# Rig de personajes en Godot

1. Inspecciona el archivo original. Cuenta triángulos, verifica materiales, ejes, escala, clips y si hay piel y huesos. Conserva el original y registra la procedencia de la copia que entra al juego.
2. Si hay un rig usable, conserva jerarquía y pesos. Si la malla es estática, observa frente y perfil antes de ubicar pivotes. Usa un esqueleto con pesos normalizados para deformar una superficie continua. Reserva las bisagras rígidas para piezas realmente separadas. Prueba una pose deliberadamente amplia para detectar estiramientos y pesos contaminados entre extremidades.
3. Usa nombres estables para huesos y pies cerca del suelo en reposo. Anima según la velocidad del controlador, con transiciones a reposo y carga. Conserva colisiones, dueño del objeto y punto de acople. Evita que las manos atraviesen la caja.
4. Verifica que el motor importe el esqueleto y que las articulaciones cambien la silueta. Comprueba pasos opuestos, giro, freno, carga, pausa y dos instancias simultáneas cuando corresponda. Revisa de cerca y desde la cámara del juego. Separa la evidencia de deformación, las pruebas de interacción y el arranque del ejecutable.

En Artemis, comprueba círculo azul para J1, rombo naranja para J2, traspaso de cajas y movimiento con FieldPilot. Registra el corte en context_core y ejecuta tests/verify.ps1.
