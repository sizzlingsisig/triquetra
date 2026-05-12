shader_type canvas_item;

uniform float intensity: hint_range(0.0, 1.0) = 0.0;
uniform vec2 direction = vec2(1.0, 0.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	for (int i = 1; i <= 6; i++) {
		float f = float(i) / 6.0;
		color += texture(TEXTURE, UV - direction * intensity * f * 0.04);
	}
	COLOR = color / 7.0;
}
