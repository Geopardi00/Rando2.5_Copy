shader_type canvas_item;

uniform vec4 underwater_tint : source_color = vec4(0.53, 0.82, 0.95, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;
uniform float shimmer_strength : hint_range(0.0, 0.25) = 0.04;
uniform float shimmer_frequency : hint_range(1.0, 40.0) = 14.0;
uniform float shimmer_speed : hint_range(0.0, 10.0) = 2.0;
uniform float wobble_strength : hint_range(0.0, 12.0) = 4.0;
uniform float wobble_frequency : hint_range(0.005, 0.1) = 0.035;
uniform float wobble_speed : hint_range(0.0, 10.0) = 2.8;

varying vec4 sprite_modulate;


void vertex() {
	sprite_modulate = COLOR;
}


void fragment() {
	vec2 pixel_position = UV / TEXTURE_PIXEL_SIZE;
	float horizontal_wobble = sin(pixel_position.y * wobble_frequency + TIME * wobble_speed);
	float vertical_wobble = sin(pixel_position.x * wobble_frequency * 0.75 - TIME * wobble_speed * 0.8);
	float size_pulse = sin(TIME * wobble_speed * 0.55) * wobble_strength * 0.35;
	vec2 wobble_pixels = vec2(horizontal_wobble, vertical_wobble * 0.45) * wobble_strength;
	wobble_pixels += (UV - vec2(0.5)) * size_pulse;
	vec2 warped_uv = UV + wobble_pixels * TEXTURE_PIXEL_SIZE;
	vec4 sprite_color = texture(TEXTURE, warped_uv);
	float first_wave = sin(UV.y * shimmer_frequency + TIME * shimmer_speed);
	float second_wave = sin((UV.x + UV.y) * shimmer_frequency * 0.65 - TIME * shimmer_speed * 0.7);
	float shimmer = (first_wave + second_wave) * 0.5;
	vec3 tinted_color = mix(sprite_color.rgb, sprite_color.rgb * underwater_tint.rgb, tint_strength);
	tinted_color *= 1.0 + shimmer * shimmer_strength;
	COLOR = vec4(tinted_color, sprite_color.a) * sprite_modulate;
}
