shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 line_color : source_color = vec4(1.0);
uniform float line_thickness : hint_range(0, 10) = 1.0;

const vec2 OFFSETS[12] = { vec2(-1, 0), vec2(0, -1), vec2(0, 1), vec2(1, 0), vec2(-0.85, 0.5), vec2(-0.5, 0.85), vec2(0.85, 0.5), vec2(0.5, 0.85), vec2(-0.85, -0.5), vec2(-0.5, -0.85), vec2(0.85, -0.5), vec2(0.5, -0.85)
};

uniform float alpha : hint_range(0.0, 1.0, 0.1) = 1.0;

// When called for each fragment, draws an outline around a sprite
float outline(vec2 size, vec2 uv, sampler2D color){
	float outline = 0.0;
	for(int i = 0; i < OFFSETS.length(); i++){
		outline += texture(color, uv + size * OFFSETS[i]).a;
	}
	return min(outline, 1.0);
}

void vertex() {
	VERTEX += (UV * 2.0 - 1.0) * line_thickness;
}

void fragment() {
	
	vec2 uv = SCREEN_UV;
	vec2 size = (SCREEN_PIXEL_SIZE * line_thickness);
	float o = min(1.0, outline(size, uv, screen_texture));
	
	vec4 screen_color = texture(screen_texture, uv);
	COLOR.rgb = mix(line_color.rgb, screen_color.rgb, screen_color.a);
 	COLOR.a = o * alpha;
	
}