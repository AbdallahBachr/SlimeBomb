shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.02, 0.03, 0.08, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.01, 0.01, 0.02, 1.0);
uniform vec4 accent_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float accent_strength = 0.12;
uniform float noise_amount = 0.04;
uniform float vignette_strength = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec4 base = mix(color_top, color_bottom, uv.y);

	vec2 center = vec2(0.5 + sin(TIME * 0.15) * 0.06, 0.3 + cos(TIME * 0.12) * 0.05);
	float dist = distance(uv, center);
	float glow = smoothstep(0.6, 0.0, dist) * accent_strength;

	float n = hash(uv * vec2(720.0, 1600.0) + TIME) - 0.5;
	base.rgb += n * noise_amount;

	float vignette = smoothstep(0.9, 0.2, distance(uv, vec2(0.5, 0.5)));
	base.rgb = mix(base.rgb, base.rgb * (1.0 - vignette_strength), 1.0 - vignette);

	base.rgb += accent_color.rgb * glow;
	COLOR = base;
}
