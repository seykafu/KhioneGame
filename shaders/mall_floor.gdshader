shader_type spatial;
// Polished mall tiling v2: checkered tiles with grout, per-tile brightness
// variation, a dark walk-lane border ringing the atrium opening, and a
// medallion around the fountain. All analytic, no textures.

uniform vec3 tile_color : source_color = vec3(0.84, 0.82, 0.78);
uniform vec3 tile_alt : source_color = vec3(0.76, 0.74, 0.71);
uniform vec3 grout : source_color = vec3(0.58, 0.56, 0.53);
uniform vec3 band_color : source_color = vec3(0.42, 0.4, 0.44);
uniform vec3 accent_gold : source_color = vec3(0.78, 0.64, 0.35);
uniform float tile_size = 1.6;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(wp.xz / tile_size);
	vec2 f = fract(wp.xz / tile_size);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(tile_color, tile_alt, checker);
	col *= 0.96 + 0.08 * hash2(cell);

	// Dark walk-lane band tracing the atrium opening (19 x 11 half extents).
	float dx = abs(wp.x) / 19.0;
	float dz = abs(wp.z) / 11.0;
	float d = max(dx, dz);
	float band = smoothstep(0.965, 0.985, d) * (1.0 - smoothstep(1.06, 1.08, d));
	col = mix(col, band_color, band * 0.9);

	// Fountain medallion: a charcoal ring with a thin gold fillet.
	float r = length(wp.xz);
	float ring = smoothstep(4.15, 4.3, r) * (1.0 - smoothstep(5.0, 5.15, r));
	col = mix(col, band_color * 0.9, ring * 0.85);
	float gold = smoothstep(4.55, 4.62, r) * (1.0 - smoothstep(4.74, 4.81, r));
	col = mix(col, accent_gold, gold);

	float line = clamp(step(f.x, 0.035) + step(f.y, 0.035), 0.0, 1.0);
	col = mix(col, grout, line * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.22, 0.4, band + ring);
	SPECULAR = 0.55;
}
