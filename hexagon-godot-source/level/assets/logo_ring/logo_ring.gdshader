shader_type spatial;
render_mode unshaded;

uniform float logo_scale = 1.0; 
uniform vec3 color : source_color; 
uniform sampler2D logo_sampler : filter_linear, repeat_enable;

void fragment() {
	ALBEDO = color;
	ALPHA = texture(logo_sampler, (UV - vec2(TIME * 0.01, 0.0)) * vec2(-logo_scale, 2.0)).a;
}
