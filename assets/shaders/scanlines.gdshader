shader_type canvas_item;

uniform float line_density = 900.0;
uniform float intensity = 0.12;
uniform float scroll_speed = 0.06;
uniform float noise_strength = 0.02;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float line = sin((uv.y + TIME * scroll_speed) * line_density) * 0.5 + 0.5;
	float n = hash(uv * vec2(800.0, 1600.0) + TIME) - 0.5;
	float alpha = (1.0 - line) * intensity + n * noise_strength;
	alpha = clamp(alpha, 0.0, 0.25);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
