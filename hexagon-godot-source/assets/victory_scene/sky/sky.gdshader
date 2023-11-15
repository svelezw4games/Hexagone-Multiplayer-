shader_type sky;


group_uniforms sky;

uniform vec3 top_color : source_color = vec3(1.0);
uniform vec3 bottom_color : source_color = vec3(1.0);
uniform vec3 sun_scatter : source_color = vec3(1.0);

uniform sampler2D lines_sampler : repeat_enable, filter_linear_mipmap;
uniform vec3 lines_color : source_color = vec3(1.0);
uniform float lines_intensity : hint_range(0.0, 10.0, 0.1) = 1.25;

vec2 LinesRayMarch(vec3 direction){
	float horizon = length(direction.xy) / 4.0;
	if (horizon > 1.0) return vec2(0.0);
	
	float density = 0.0;
	float height_density = 0.0;
	
	float depth = 0.0;
	int steps = 128;
	
	vec3 sample_point = vec3(0.0, 0.0, 0.0);
	int step_offset = 64;
	
	for(int i = step_offset; i < steps + step_offset; i++){
		float step_percent = float(i) / float(steps);
		sample_point = direction * 0.1 * step_percent;
		float d_1 = texture(lines_sampler, (sample_point.xy - TIME * 0.001) * 1.6).x;
		float d_2 = texture(lines_sampler, (sample_point.xy + TIME * 0.002) * 1.2).x;
		float d = d_1 * d_2 ;
		depth += d * step_percent;
		density += d;
		
	}
	
	return vec2(clamp((density / float(steps)) * (1.0 - horizon), 0.0, 1.0), depth);
}

void sky() {
	float horizon_mask = abs(EYEDIR.y);
	vec3 sky_gradient = mix(top_color.rgb, bottom_color.rgb, SKY_COORDS.y);
	vec3 sunset_color = sun_scatter * (1.0 - horizon_mask);
	vec3 sky_color = clamp(sky_gradient + sunset_color, 0.0, 1.0);
	COLOR.rgb = sky_color;
	vec2 lines = LinesRayMarch(vec3(EYEDIR.xz / clamp(-EYEDIR.y, 0.0, 1.0), 1.0));
	
	COLOR.rgb += lines_color * (1.0 - exp(-lines.x * 6.0)) * lines_intensity;
}
