shader_type canvas_item;
render_mode unshaded;
uniform float intensity : hint_range(0.0, 1.0) = 0.18;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.32, 1.18, length(p));
	COLOR = vec4(0.0, 0.015, 0.025, edge * intensity * 0.55);
}
