shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color_start : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform vec4 outline_color_end : source_color = vec4(0.52, 0.78, 1.0, 1.0);
uniform float outline_width : hint_range(1.0, 12.0, 0.5) = 6.0;
uniform float color_cycle_seconds : hint_range(0.25, 10.0) = 2.5;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.1;


void fragment() {
	float center_alpha = texture(TEXTURE, UV).a;
	float surrounding_alpha = 0.0;
	vec2 full_offset = TEXTURE_PIXEL_SIZE * outline_width;
	vec2 half_offset = full_offset * 0.5;
	vec2 full_diagonal = full_offset * 0.70710678;
	vec2 half_diagonal = half_offset * 0.70710678;

	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(full_offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(full_offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, full_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, full_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + full_diagonal).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - full_diagonal).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(full_diagonal.x, -full_diagonal.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-full_diagonal.x, full_diagonal.y)).a);

	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(half_offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(half_offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, half_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, half_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + half_diagonal).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - half_diagonal).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(half_diagonal.x, -half_diagonal.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-half_diagonal.x, half_diagonal.y)).a);

	float center_mask = step(alpha_threshold, center_alpha);
	float neighbor_mask = step(alpha_threshold, surrounding_alpha);
	float outline_alpha = (1.0 - center_mask) * neighbor_mask;

	float cycle_duration = max(color_cycle_seconds, 0.01);
	float color_mix = sin(TIME * TAU / cycle_duration) * 0.5 + 0.5;
	vec4 outline_color = mix(outline_color_start, outline_color_end, color_mix);

	COLOR = vec4(outline_color.rgb, outline_color.a * outline_alpha);
}
