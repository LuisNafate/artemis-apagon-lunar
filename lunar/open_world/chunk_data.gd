class_name ChunkData
extends RefCounted

## Datos puros de un chunk: alturas, celdas transitables, rocas y depositos.
## Los puntos de rocas y depositos estan en coordenadas globales.

var coord := Vector2i.ZERO
var size := 16.0
var samples := 17
var heights := PackedFloat32Array()
var walkable := PackedByteArray()
var rocks: Array[Dictionary] = []
var deposits: Array[Dictionary] = []


## Altura interpolada; `local` es la posicion dentro del chunk (0..size en x y z).
func height_at(local: Vector2) -> float:
	var step := size / float(samples - 1)
	var gx := clampf(local.x / step, 0.0, float(samples - 1))
	var gz := clampf(local.y / step, 0.0, float(samples - 1))
	var ix := mini(int(gx), samples - 2)
	var iz := mini(int(gz), samples - 2)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	var h00 := heights[iz * samples + ix]
	var h10 := heights[iz * samples + ix + 1]
	var h01 := heights[(iz + 1) * samples + ix]
	var h11 := heights[(iz + 1) * samples + ix + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)
