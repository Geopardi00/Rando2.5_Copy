shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 16.0) = 2.0;

void fragment() {
    vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;

    vec4 col = texture(TEXTURE, UV) * 0.20;
    col += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.16;
    col += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.16;
    col += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.16;
    col += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.16;
    col += texture(TEXTURE, UV + vec2(px.x, px.y)) * 0.09;
    col += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.09;
    col += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.09;
    col += texture(TEXTURE, UV + vec2(-px.x, -px.y)) * 0.09;

    COLOR = col;
}