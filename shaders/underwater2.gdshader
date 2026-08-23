shader_type canvas_item;
render_mode unshaded;

uniform vec3 water : source_color = vec3(0.4, 0.6, 0.8);
uniform float effect_strength : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float speed : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float wave : hint_range(0.0, 100.0, 0.1) = 20.0;
uniform float warp : hint_range(0.1, 20.0, 0.01) = 5.0;

uniform sampler2D screen_texture
	: hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	float time = TIME * speed;
	vec2 s = UV * wave + time;

	float horizontal_warp = 0.0;
	horizontal_warp += sin(s.x - s.y) * warp * 0.001 * sin(s.y);
	horizontal_warp += cos(s.x + s.y) * warp * 0.001 * cos(s.y);

	vec2 distortion = vec2(horizontal_warp, 0.0);

	vec4 original_scene = texture(screen_texture, SCREEN_UV);
	vec4 warped_scene = texture(
	screen_texture,
	SCREEN_UV + distortion
);

vec3 tinted_water = warped_scene.rgb * water;
COLOR = vec4(tinted_water, 1.0);
}
