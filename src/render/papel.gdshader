shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

// Shader unico "papel": cartulina mate, facetas planas y grano fino.
// Lo usa todo el juego (suelo, craters, piezas, modelos GLB) para que
// compartan el mismo acabado.

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 4.0) = 0.0;
uniform float unlit : hint_range(0.0, 1.0) = 0.0;
uniform bool flat_facets = true;
uniform float facet_variation : hint_range(0.0, 0.3) = 0.07;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.07;
uniform float grain_scale = 38.0;
// Terreno: aplana el relieve cerca de la base y recorta el borde trasero del suelo.
uniform float albedo_gain = 1.0;
uniform vec4 relief_rect = vec4(0.0);
uniform float relief_flat = 0.0;
uniform float relief_ramp = 0.0;
uniform bool back_edge_cut = false;

varying vec3 w_pos;
varying flat float face_seed;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	if (relief_ramp > 0.0) {
		vec3 base_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec2 outside = max(relief_rect.xy - base_pos.xz, base_pos.xz - relief_rect.zw);
		float reach = length(max(outside, vec2(0.0)));
		VERTEX.y *= smoothstep(relief_flat, relief_flat + relief_ramp, reach);
	}
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	face_seed = hash21(VERTEX.xz * 17.3 + VERTEX.y * 5.1 + NORMAL.xy * 3.7);
}

void fragment() {
	if (back_edge_cut) {
		float edge = -16.1 - 0.23 * w_pos.x + sin((w_pos.x + 54.0) / 4.5 * 1.43) * 0.63;
		if (w_pos.z < edge) {
			discard;
		}
	}
	vec3 base = albedo_color.rgb * albedo_gain * COLOR.rgb;
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	if (flat_facets) {
		vec3 face = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(face, NORMAL) < 0.0) {
			face = -face;
		}
		NORMAL = face;
	}
	vec3 world_normal = abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 plane = w_pos.xy;
	if (world_normal.y >= max(world_normal.x, world_normal.z)) {
		plane = w_pos.xz;
	} else if (world_normal.x >= world_normal.z) {
		plane = w_pos.zy;
	}
	float fibre = value_noise(plane * grain_scale) * 0.65
		+ value_noise(plane * grain_scale * 2.9) * 0.35;
	float tone = (face_seed - 0.5) * 2.0 * facet_variation;
	base *= 1.0 + tone + (fibre - 0.5) * 2.0 * grain_strength;
	ALBEDO = base * (1.0 - unlit);
	EMISSION = emission_color.rgb * emission_energy + base * unlit;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
