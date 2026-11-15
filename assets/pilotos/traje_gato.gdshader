shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 player_tint : source_color = vec4(1.0);

void fragment() {
	vec3 original = texture(base_texture, UV).rgb;
	float lightness = dot(original, vec3(0.2126, 0.7152, 0.0722));
	float warm = smoothstep(0.035, 0.20, original.r - original.b);
	float highlight = smoothstep(0.54, 0.96, lightness);
	vec3 palette = mix(player_tint.rgb * 0.75, vec3(0.97), highlight * 0.73);
	palette *= 0.12 + 0.98 * lightness;
	ALBEDO = mix(original, palette, 0.59 + warm * 0.37);
	ROUGHNESS = 0.88;
	SPECULAR = 0.26;
}
