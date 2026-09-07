shader_type canvas_item;
render_mode unshaded;

const float SEAM_PIXELS = 48.0;
uniform vec4 district_grade : source_color = vec4(1.0);
uniform vec4 cycle_tint : source_color = vec4(1.0);
uniform float cycle_brightness : hint_range(0.0, 1.2) = 1.0;
uniform float cycle_saturation : hint_range(0.0, 1.4) = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float edge_distance = min(UV.x, 1.0 - UV.x);
	float seam_width = TEXTURE_PIXEL_SIZE.x * SEAM_PIXELS;
	float seam_weight = 1.0 - smoothstep(0.0, seam_width, edge_distance);
	vec2 left_uv = vec2(edge_distance, UV.y);
	vec2 right_uv = vec2(1.0 - edge_distance, UV.y);
	vec4 matched_edge = mix(
		texture(TEXTURE, left_uv),
		texture(TEXTURE, right_uv),
		0.5
	);
	vec4 tiled = mix(source, matched_edge, seam_weight);
	float luminance = dot(tiled.rgb, vec3(0.2126, 0.7152, 0.0722));
	tiled.rgb = mix(vec3(luminance), tiled.rgb, cycle_saturation);
	tiled.rgb *= district_grade.rgb * cycle_tint.rgb * cycle_brightness;
	COLOR = tiled * COLOR;
}
