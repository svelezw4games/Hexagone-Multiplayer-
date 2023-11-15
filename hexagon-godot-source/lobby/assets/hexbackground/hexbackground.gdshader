shader_type canvas_item;

uniform float hexagon_size = 100.0;
const vec2 s = vec2(1, 1.7320508);

uniform vec3 dark_color : source_color;
uniform vec3 light_color : source_color;

float random(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

// GetHex Method by Gary "Shane" Warne
// https://www.shadertoy.com/user/Shane

vec4 getHex(vec2 p){
	vec4 hC = floor(vec4(p, p - vec2(0.5, 1.0))/s.xyxy) + 0.5;
	vec4 h = vec4(p - hC.xy*s, p - (hC.zw + 0.5)*s);
	return dot(h.xy, h.xy)<dot(h.zw, h.zw) ? vec4(h.xy, hC.xy) : vec4(h.zw, hC.zw + vec2(0.5, 1.0));
}

void fragment() {
	vec2 uv = FRAGCOORD.xy / hexagon_size;
	vec4 hexinfo = getHex(uv + vec2(0.0, TIME * 0.1));
	float hexa = (sin(random(hexinfo.zw) * 10.0 + TIME * 0.2) + 1.0) / 2.0;
	float light_hexa = smoothstep(0.1, 0.0, hexa * 10.0);
	float dark_hexa = smoothstep(0.0, 1.0, hexa);
	float gradient_distance = distance(UV, vec2(0.5, 1.0)) * 0.5;
	vec3 gradient_color = mix(dark_color, light_color, gradient_distance);
	gradient_color -= dark_hexa * UV.y * 0.025;
	COLOR.rgb = mix(gradient_color, light_color, light_hexa * (1.0 - UV.y) * 0.4);
}
