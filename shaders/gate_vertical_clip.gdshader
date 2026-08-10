shader_type canvas_item;

uniform float clip_uv_y : hint_range(0.0, 1.0, 0.001) = 0.0;


void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	if (UV.y < clip_uv_y) {
		base_color.a = 0.0;
	}
	COLOR = base_color;
}
