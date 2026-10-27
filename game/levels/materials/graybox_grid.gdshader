shader_type spatial;
// World-space grid for graybox geometry: minor lines every grid_size meters,
// major lines every major_every cells, so scale reads at a glance.

uniform vec3 base_color : source_color = vec3(0.55);
uniform vec3 line_color : source_color = vec3(0.25);
uniform float grid_size = 1.0;
uniform float major_every = 4.0;
uniform float line_width = 0.025;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 uv, float cell, float width) {
	vec2 dist = abs(fract(uv / cell - 0.5) - 0.5) * cell;
	vec2 aa = fwidth(uv);
	vec2 line = 1.0 - smoothstep(vec2(width), vec2(width) + aa, dist);
	return max(line.x, line.y);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float minor = grid_line(uv, grid_size, line_width);
	float major = grid_line(uv, grid_size * major_every, line_width * 2.0);
	ALBEDO = mix(base_color, line_color, max(minor * 0.5, major));
	ROUGHNESS = 0.9;
}
