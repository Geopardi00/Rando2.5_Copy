shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float force : hint_range(0.0, 0.05) = 0.012;
uniform float start_radius : hint_range(0.0, 0.5) = 0.03;
uniform float end_radius : hint_range(0.0, 0.75) = 0.48;
uniform float thickness : hint_range(0.005, 0.25) = 0.045;
uniform vec4 underwater_tint : source_color = vec4(0.0, 0.4, 0.6, 0.3);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


void fragment() {
	// UV is local to the square ShockwaveEffect sprite, so vec2(0.5)
	// always follows the mine instead of incorrectly using screen center.
	vec2 local_vector = UV - vec2(0.5);
	float distance_from_center = length(local_vector);
	float radius = mix(start_radius, end_radius, progress);
	float distance_from_ring = abs(distance_from_center - radius);
	float ring_mask = 1.0 - smoothstep(thickness * 0.35, thickness, distance_from_ring);
	float lifecycle_fade = 1.0 - smoothstep(0.78, 1.0, progress);
	float visible_ring = ring_mask * lifecycle_fade;

	vec2 direction = local_vector / max(distance_from_center, 0.0001);
	float wave_profile = sin(clamp(distance_from_ring / max(thickness, 0.0001), 0.0, 1.0) * 3.14159265);
	vec2 distorted_uv = SCREEN_UV + direction * force * wave_profile * visible_ring;
	vec4 screen_color = texture(SCREEN_TEXTURE, distorted_uv);
	screen_color.rgb = mix(screen_color.rgb, underwater_tint.rgb, underwater_tint.a * visible_ring);

	// Transparent outside the ring: this is what removes the blue carrier box.
	COLOR = vec4(screen_color.rgb, visible_ring);
}
