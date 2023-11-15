shader_type sky;

group_uniforms sky;

uniform vec3 top_color : source_color = vec3(1.0);
uniform vec3 bottom_color : source_color = vec3(1.0);
uniform vec3 sun_scatter : source_color = vec3(1.0);


void sky() {
	float horizon_mask = abs(EYEDIR.y);
	vec3 sky_gradient = mix(top_color.rgb, bottom_color.rgb, SKY_COORDS.y);
	vec3 sunset_color = sun_scatter * (1.0 - horizon_mask);
	vec3 sky_color = clamp(sky_gradient + sunset_color, 0.0, 1.0);
	COLOR.rgb = sky_color;
}
