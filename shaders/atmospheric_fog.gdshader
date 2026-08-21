shader_type canvas_item;

uniform vec4 fog_tint : source_color = vec4(0.68, 0.76, 0.84, 1.0);
uniform float opacity : hint_range(0.0, 0.35, 0.005) = 0.1;
uniform vec2 uv_scale = vec2(0.6, 0.9);
uniform vec2 scroll_velocity = vec2(0.001, -0.0003);
uniform float distortion_strength : hint_range(0.0, 0.1, 0.001) = 0.02;

void fragment() {
	vec2 primary_uv = UV * uv_scale + scroll_velocity * TIME;
	vec2 distortion_uv = UV * (uv_scale * 0.57) - scroll_velocity.yx * TIME * 0.63 + vec2(0.31, 0.67);
	vec2 distortion = texture(TEXTURE, fract(distortion_uv)).rg * 2.0 - 1.0;
	float density = texture(TEXTURE, fract(primary_uv + distortion * distortion_strength)).r;
	density = smoothstep(0.27, 0.76, density);
	COLOR = vec4(fog_tint.rgb, density * opacity * fog_tint.a);
}
