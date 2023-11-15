shader_type spatial;

uniform vec3 base_color : source_color;
uniform vec3 light_color : source_color;
uniform float emission_intensity : hint_range(0.0, 2.0, 0.1) = 0.0;
uniform sampler2D hexagon_texture_sampler : filter_linear_mipmap_anisotropic, repeat_disable;

void fragment() {
	vec2 hexagon_texture = texture(hexagon_texture_sampler, UV).xy;
	float mask = hexagon_texture.x;
	EMISSION = light_color * emission_intensity * 1.5 * mask;
	ROUGHNESS = mix(0.55, 0.65, mask);
	ALBEDO = mix(base_color, base_color * vec3(0.0), mask * clamp(emission_intensity, 0.2, 1.0));
}
