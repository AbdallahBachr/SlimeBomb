shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 0.35);
uniform float intensity = 1.2;
uniform float pulse_speed = 1.6;
uniform float pulse_strength = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;
	float a = tex.a * glow_color.a * intensity * pulse;
	COLOR = vec4(glow_color.rgb, a);
}
