shader_type spatial;
// Prince's Island park terrain: summer lawn with sun-patch mottling, an
// analytically painted gravel path ring and dock spur, a sandy rim around
// the lagoon hollow, a river-gravel beach at the coast, and an underwater
// fade into the Bow's milky teal. Radial math only — Metal-safe.

uniform vec3 lawn_color : source_color = vec3(0.42, 0.68, 0.32);
uniform vec3 lawn_alt : source_color = vec3(0.32, 0.58, 0.27);
uniform vec3 gravel : source_color = vec3(0.72, 0.68, 0.6);
uniform vec3 river_stone : source_color = vec3(0.62, 0.6, 0.55);
uniform sampler2D noise_tex;
uniform sampler2D detail_normal : hint_normal;
uniform float noise_scale = 0.06;
uniform float normal_strength = 0.3;
uniform float base_radius = 46.0;
uniform float path_radius = 16.0;
uniform vec2 lagoon_center = vec2(-11.0, -1.0);
uniform vec2 lagoon_radii = vec2(7.5, 5.5);

varying vec3 world_pos;

float coast_radius(float theta) {
	float wob = 2.6 * sin(3.0 * theta + 1.7) + 1.7 * sin(5.0 * theta + 4.2)
			+ 1.1 * sin(8.0 * theta + 0.9);
	float d = abs(mod(theta - 1.5707963 + 3.14159265, 6.2831853) - 3.14159265);
	wob *= smoothstep(0.55, 1.1, d);
	return base_radius + wob;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, world_pos.xz * noise_scale).r;
	float n2 = texture(noise_tex, world_pos.xz * noise_scale * 5.0).r;
	float d = length(world_pos.xz);
	float theta = atan(world_pos.z, world_pos.x);
	float coast = coast_radius(theta);

	// Lawn with big soft sun patches; higher ground dries golden.
	vec3 col = mix(lawn_color, lawn_alt, smoothstep(0.35, 0.65, n));
	col *= 0.95 + 0.1 * n2;
	float dry = smoothstep(0.55, 1.05, world_pos.y);
	col = mix(col, vec3(0.62, 0.66, 0.34), dry * 0.6);

	// Gravel: the path ring (open to the south), the dock spur, and a spur
	// to the off-leash meadow in the north.
	float ang_gap = abs(mod(theta - 1.5707963 + 3.14159265, 6.2831853) - 3.14159265);
	float on_ring = (1.0 - smoothstep(1.1, 1.5, abs(d - path_radius)))
			* smoothstep(0.42, 0.62, ang_gap);
	float on_dock = (1.0 - smoothstep(1.4, 1.8, abs(world_pos.x)))
			* smoothstep(13.0, 14.5, world_pos.z) * (1.0 - smoothstep(44.0, 46.0, world_pos.z));
	float on_north = (1.0 - smoothstep(1.2, 1.6, abs(world_pos.x)))
			* smoothstep(-16.5, -15.0, -world_pos.z) * (1.0 - smoothstep(22.5, 24.0, -world_pos.z));
	float path = clamp(on_ring + on_dock + on_north, 0.0, 1.0) * (1.0 - smoothstep(0.5, 0.9, world_pos.y));
	vec3 path_col = gravel * (0.92 + 0.14 * n2);
	col = mix(col, path_col, path * 0.95);

	// Sandy rim where the ground dips into the lagoon.
	vec2 lag = (world_pos.xz - lagoon_center) / lagoon_radii;
	float lag_d = length(lag);
	float lag_rim = smoothstep(0.78, 0.95, lag_d) * (1.0 - smoothstep(1.12, 1.3, lag_d));
	col = mix(col, vec3(0.85, 0.78, 0.6), lag_rim * 0.85);
	float lag_bed = 1.0 - smoothstep(0.55, 0.85, lag_d);
	col = mix(col, vec3(0.55, 0.56, 0.5), lag_bed);

	// River-stone beach at the coast, then the underwater teal fade.
	float beach = smoothstep(coast - 3.5, coast - 1.0, d) * (1.0 - smoothstep(0.2, 0.45, world_pos.y));
	col = mix(col, river_stone * (0.9 + 0.2 * n2), beach * 0.9);
	float seabed = 1.0 - smoothstep(-3.2, -0.4, world_pos.y);
	col = mix(col, vec3(0.1, 0.34, 0.36), seabed);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.7, path);
	NORMAL_MAP = texture(detail_normal, world_pos.xz * noise_scale * 4.0).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
