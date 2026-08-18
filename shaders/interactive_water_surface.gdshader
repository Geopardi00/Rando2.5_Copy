shader_type canvas_item;
render_mode unshaded;

uniform vec4 surface_color : source_color = vec4(0.12, 0.62, 0.82, 0.72);
uniform vec4 highlight_color : source_color = vec4(0.72, 0.95, 1.0, 0.9);
uniform float ripple_speed : hint_range(0.0, 6.0, 0.05) = 1.15;
uniform float ripple_scale : hint_range(0.002, 0.12, 0.001) = 0.028;
uniform float distortion_strength : hint_range(0.0, 12.0, 0.1) = 2.4;
uniform float horizontal_flow_speed : hint_range(-100.0, 100.0, 0.5) = 12.0;
uniform float noise_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float surface_opacity : hint_range(0.0, 1.0, 0.01) = 0.82;

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


void fragment() {
	float time = TIME * ripple_speed;
	float flowing_x = local_position.x + TIME * horizontal_flow_speed;
	float first_wave = sin(flowing_x * ripple_scale + time);
	float second_wave = sin(
		flowing_x * ripple_scale * 0.57
		+ local_position.y * ripple_scale * 1.9
		- time * 0.73
	);
	float distorted_phase = flowing_x * ripple_scale * 1.8
		+ (first_wave + second_wave) * 0.5 * distortion_strength;
	float small_ripples = sin(distorted_phase - time * 1.35) * 0.5 + 0.5;
	float shimmer = smoothstep(0.68, 0.98, small_ripples);
	float movement = (first_wave + second_wave) * 0.25 + 0.5;
	float highlight_mix = clamp(shimmer * 0.55 + movement * noise_strength, 0.0, 0.72);
	vec3 final_color = mix(surface_color.rgb, highlight_color.rgb, highlight_mix);
	float alpha_motion = mix(0.9, 1.0, movement);
	COLOR = vec4(final_color, surface_color.a * surface_opacity * alpha_motion);
}
