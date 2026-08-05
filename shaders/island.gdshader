shader_type spatial;
// Terrain shader for Ahalo's sculpted island mesh. Blends sand, grass, and
// summit rock by height and coast distance, with noise variation, micro
// normals, and a wet-sand band that follows the analytic coastline (the
// same function the mesh generator and water shader use).

uniform vec3 sand_color : source_color = vec3(0.93, 0.85, 0.63);
uniform vec3 sand_alt : source_color = vec3(0.85, 0.75, 0.52);
uniform vec3 grass_color : source_color = vec3(0.42, 0.7, 0.34);
uniform vec3 grass_alt : source_color = vec3(0.33, 0.6, 0.27);
uniform vec3 rock_color : source_color = vec3(0.55, 0.55, 0.58);
uniform sampler2D noise_tex;
uniform sampler2D detail_normal : hint_normal;
uniform float noise_scale = 0.06;
uniform float normal_strength = 0.35;

varying vec3 world_pos;

float coast_radius(float theta) {
	float wob = 2.6 * sin(3.0 * theta + 1.7) + 1.7 * sin(5.0 * theta + 4.2)
			+ 1.1 * sin(8.0 * theta + 0.9);
	float d = abs(mod(theta - 1.5707963 + 3.14159265, 6.2831853) - 3.14159265);
	wob *= smoothstep(0.55, 1.1, d);
	return 40.0 + wob;
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
	float grass_r = coast * 0.74;

	vec3 sand = mix(sand_color, sand_alt, smoothstep(0.3, 0.7, n));
	vec3 grass = mix(grass_color, grass_alt, smoothstep(0.3, 0.7, n));
	// Grass covers the raised interior; sand the beach and shallows.
	float grass_mask = (1.0 - smoothstep(grass_r - 2.0, grass_r - 0.4, d))
			* smoothstep(0.12, 0.28, world_pos.y);
	// Summit terrace turns to rock.
	float rock_mask = smoothstep(2.55, 2.95, world_pos.y);
	vec3 col = mix(sand, grass, clamp(grass_mask, 0.0, 1.0));
	col = mix(col, rock_color, rock_mask);
	col *= 0.95 + 0.1 * n2;

	// Wet band hugging the true coastline.
	float shore = smoothstep(coast - 2.8, coast + 0.6, d) * (1.0 - smoothstep(0.15, 0.4, world_pos.y));
	col = mix(col, col * 0.66, shore * 0.85);
	// Below the waterline the seabed fades into deep-water blue so the mesh
	// edge disappears instead of reading as a pale square under the ocean.
	float seabed = 1.0 - smoothstep(-3.2, -0.4, world_pos.y);
	col = mix(col, vec3(0.1, 0.3, 0.44), seabed);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.45, shore);
	NORMAL_MAP = texture(detail_normal, world_pos.xz * noise_scale * 4.0).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
