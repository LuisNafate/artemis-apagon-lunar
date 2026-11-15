shader_type canvas_item;

// Ondulacion suave y un destello que cruza el logo de lado a lado.
uniform float wave_amount = 0.014;
uniform float wave_speed = 2.2;

void fragment() {
	vec2 uv = UV;
	uv.y += sin(UV.x * 9.0 + TIME * wave_speed) * wave_amount;
	vec4 color = texture(TEXTURE, uv);
	float sweep = fract(TIME * 0.2) * 1.8 - 0.4;
	float band = smoothstep(0.1, 0.0, abs(UV.x + UV.y * 0.35 - sweep));
	color.rgb += vec3(1.0, 0.95, 0.8) * band * 0.35 * color.a;
	COLOR = color;
}
