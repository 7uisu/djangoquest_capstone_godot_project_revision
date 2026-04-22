shader_type canvas_item;

uniform vec2 spotlight_pos = vec2(0.5, 0.5);
uniform vec2 spotlight_size = vec2(0.15, 0.15); // width, height in normalized coords
uniform float softness : hint_range(0.0, 0.2) = 0.03;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);

void fragment() {
    vec2 diff = (UV - spotlight_pos) / spotlight_size;
    float dist = length(diff);
    float mask = smoothstep(1.0, 1.0 + softness / max(spotlight_size.x, spotlight_size.y), dist);
    COLOR = vec4(overlay_color.rgb, overlay_color.a * mask);
}
