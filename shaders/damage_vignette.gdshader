shader_type canvas_item;

uniform float clear_radius : hint_range(0.0, 0.7, 0.01) = 0.16;
uniform float full_edge_radius : hint_range(0.3, 1.0, 0.01) = 0.72;
uniform float falloff_power : hint_range(0.25, 4.0, 0.05) = 1.15;


void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;
	float radial_distance = length(centered_uv);
	float edge_strength = smoothstep(clear_radius, full_edge_radius, radial_distance);
	edge_strength = pow(edge_strength, falloff_power);
	COLOR.a *= edge_strength;
}
