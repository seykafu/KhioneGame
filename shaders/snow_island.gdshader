shader_type spatial;
// Calgary's snowfield terrain. White snowpack with cold blue shadow tones
// and sun sparkle, a plowed crescent road and dock path painted analytically,
// an icy sheen near the waterline, and an underwater fade to deep water.
// Same Metal-safe playbook as Ahalo: radial math, no depth textures.

uniform vec3 snow_color : source_color = vec3(0.93, 0.95, 0.99);
uniform vec3 snow_alt : source_color = vec3(0.84, 0.88, 0.96);
uniform vec3 asphalt : source_color = vec3(0.27, 0.28, 0.32);
uniform vec3 ice_shore : source_color = vec3(0.72, 0.83, 0.92);
uniform sampler2D noise_tex;
uniform sampler2D detail_normal : hint_normal;
uniform float noise_scale = 0.06;
uniform float normal_strength = 0.3;
uniform float base_radius = 46.0;
uniform float road_radius = 16.0;

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

	vec3 col = mix(snow_color, snow_alt, smoothstep(0.3, 0.7, n));
	col *= 0.97 + 0.06 * n2;

	// The plowed crescent road (gap open to the south) and the dock path.
	float ang_gap = abs(mod(theta - 1.5707963 + 3.14159265, 6.2831853) - 3.14159265);
	float on_ring = (1.0 - smoothstep(1.35, 1.75, abs(d - road_radius)))
			* smoothstep(0.42, 0.62, ang_gap);
	float on_path = (1.0 - smoothstep(1.6, 2.0, abs(world_pos.x)))
			* smoothstep(13.0, 14.5, world_pos.z) * (1.0 - smoothstep(44.0, 46.0, world_pos.z));
	float road = clamp(on_ring + on_path, 0.0, 1.0) * (1.0 - smoothstep(0.5, 0.9, world_pos.y));
	// Plow leaves streaks; snow creeps back over the edges.
	vec3 road_col = mix(asphalt, snow_alt, smoothstep(0.55, 0.9, n2) * 0.55);
	col = mix(col, road_col, road * 0.92);

	// Ice apron at the waterline: slick, pale, blue.
	float apron = smoothstep(coast - 3.0, coast - 0.5, d) * (1.0 - smoothstep(0.15, 0.4, world_pos.y));
	col = mix(col, ice_shore, apron * 0.85);

	// Below the waterline the bed fades into cold deep water.
	float seabed = 1.0 - smoothstep(-3.2, -0.4, world_pos.y);
	col = mix(col, vec3(0.08, 0.2, 0.33), seabed);

	ALBEDO = col;
	// Snow sparkle: rare noise peaks flash like sun on fresh powder.
	float sparkle = step(0.986, texture(noise_tex, world_pos.xz * 0.9).r) * (1.0 - road) * (1.0 - seabed);
	EMISSION = vec3(0.9, 0.95, 1.0) * sparkle * 0.6;
	ROUGHNESS = mix(mix(0.85, 0.5, road), 0.12, apron);
	NORMAL_MAP = texture(detail_normal, world_pos.xz * noise_scale * 4.0).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
