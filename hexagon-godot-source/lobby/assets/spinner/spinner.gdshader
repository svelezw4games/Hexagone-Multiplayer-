shader_type canvas_item;

void fragment() {
	float a = TIME * 4.0;
	mat2 rot = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	vec2 pos = UV - vec2(0.5);
	pos = rot * pos;
	float angle = (atan(pos.y, pos.x) + PI) / PI;
	
	float dist = 1.0 - distance(UV, vec2(0.5));
	float o = 0.02;
	COLOR.a = max(0.0, smoothstep(0.6 - o, 0.6 + o, dist) - smoothstep(0.75 - o, 0.75 + o, dist));
	COLOR.a *= clamp(angle, 0.0, 1.0);
}
