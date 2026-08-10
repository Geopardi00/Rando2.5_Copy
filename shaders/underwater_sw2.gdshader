shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float width : hint_range(0.001, 0.25, 0.001) = 0.04;
uniform float strength : hint_range(0.0, 0.1, 0.001) = 0.02;
uniform float aberration : hint_range(0.0, 1.0, 0.001) = 0.425;
uniform float feather : hint_range(0.001, 0.25, 0.001) = 0.04;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;


void fragment() {
	vec2 screen_uv = SCREEN_UV;
	float aspect_ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 from_center = screen_uv - center;
	from_center.x *= aspect_ratio;
	float distance_from_center = length(from_center);

	float safe_width = max(width, 0.001);
	float safe_feather = max(feather, 0.001);
	float outer_mask = 1.0 - smoothstep(radius, radius + safe_feather, distance_from_center);
	float inner_mask = smoothstep(
		max(radius - safe_width - safe_feather, 0.0),
		max(radius - safe_width, 0.0001),
		distance_from_center
	);
	float active = smoothstep(0.001, 0.01, radius);
	float ring_mask = outer_mask * inner_mask * active;

	vec2 radial_direction = from_center / max(distance_from_center, 0.0001);
	radial_direction.x /= aspect_ratio;
	vec2 offset = radial_direction * strength * ring_mask;
	vec2 aberration_offset = offset * aberration;
	vec2 distorted_uv = screen_uv - offset;

	vec4 red_sample = texture(screen_texture, distorted_uv + aberration_offset);
	vec4 green_sample = texture(screen_texture, distorted_uv);
	vec4 blue_sample = texture(screen_texture, distorted_uv - aberration_offset);
	vec4 original_sample = texture(screen_texture, screen_uv);
	vec4 distorted_sample = vec4(red_sample.r, green_sample.g, blue_sample.b, original_sample.a);

	COLOR = mix(original_sample, distorted_sample, ring_mask);
}
