shader_type spatial;
render_mode unshaded;

uniform vec3 color : source_color;

void fragment() {
	float offset = 0.001;
	float base_dist = distance(vec2(0.5), UV);
	float rings = smoothstep(0.5 - offset, 0.5 + offset, (1.0 - base_dist) * sin(base_dist * 40.0 * PI - TIME));
	float circle_mask =smoothstep(0.45 - offset, 0.45 + offset, base_dist);
	float wave_mask = smoothstep(0.0, 0.1, sin((UV.x + UV.y + TIME * 0.01) * PI * 20.0));
	ALBEDO = color;
	ALPHA = min(1.0, (1.0 - circle_mask) + rings) * (wave_mask * 0.1 + 0.9) ;
}
