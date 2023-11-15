shader_type particles;

uniform float base_scale : hint_range(0.0, 1.0, 0.1) = 1.0;
uniform sampler2D scale_curve;

float rand_from_seed(in uint seed) {
  int k;
  int s = int(seed);
  if (s == 0)
    s = 305420679;
  k = s / 127773;
  s = 16807 * (s - k * 127773) - 2836 * k;
  if (s < 0)
    s += 2147483647;
  seed = uint(s);
  return float(seed % uint(65536)) / 65535.0;
}

uint hash(uint x) {
  x = ((x >> uint(16)) ^ x) * uint(73244475);
  x = ((x >> uint(16)) ^ x) * uint(73244475);
  x = (x >> uint(16)) ^ x;
  return x;
}

void start() {
	uint seed = hash(NUMBER + uint(1) + RANDOM_SEED);
	CUSTOM.x = rand_from_seed(seed);
	CUSTOM.y = TIME;
	vec3 position = vec3(cos(CUSTOM.x * TAU), 0.0, sin(CUSTOM.x * TAU));
	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz + position;
	VELOCITY = mix(position, vec3(0.0, 1.0, 0.0), 0.8) * 2.0;
}

void process() {
	float time_percent = (TIME - CUSTOM.y) / LIFETIME;
	VELOCITY *= 0.98;
	float scale = base_scale * (texture(scale_curve, vec2(time_percent, 0.0)).x);
	TRANSFORM[0].xyz = EMISSION_TRANSFORM[0].xyz * scale;
	TRANSFORM[1].xyz = EMISSION_TRANSFORM[1].xyz * scale;
	TRANSFORM[2].xyz = EMISSION_TRANSFORM[1].xyz * scale;
}
