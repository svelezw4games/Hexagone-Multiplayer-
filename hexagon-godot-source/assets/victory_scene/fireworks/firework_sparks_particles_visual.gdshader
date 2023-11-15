shader_type spatial;


void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb;
	ALPHA = step(0.5, 1.0 - length(UV - vec2(0.5))) * COLOR.a;
}