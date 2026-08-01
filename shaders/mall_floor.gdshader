shader_type spatial;
// Polished mall tiling: checkered tiles with grout lines, glossy finish.

uniform vec3 tile_color : source_color = vec3(0.84, 0.82, 0.78);
uniform vec3 tile_alt : source_color = vec3(0.76, 0.74, 0.71);
uniform vec3 grout : source_color = vec3(0.58, 0.56, 0.53);
uniform float tile_size = 1.7;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(wp.xz / tile_size);
	vec2 f = fract(wp.xz / tile_size);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(tile_color, tile_alt, checker);
	float line = clamp(step(f.x, 0.035) + step(f.y, 0.035), 0.0, 1.0);
	col = mix(col, grout, line * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.22;
	SPECULAR = 0.55;
}
