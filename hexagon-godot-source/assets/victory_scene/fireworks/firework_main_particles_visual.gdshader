shader_type spatial;
render_mode particle_trails;

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb;
	ALPHA = (1.0 - UV.y) * 1.45 * COLOR.a;
}
