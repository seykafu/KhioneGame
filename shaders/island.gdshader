shader_type spatial;
// Ground shader for Ahalo: noise-broken color variation, micro normal
// detail, and a darker wet-sand band near the waterline (radial).

uniform vec3 base_color : source_color = vec3(0.93, 0.85, 0.63);
uniform vec3 alt_color : source_color = vec3(0.85, 0.75, 0.52);
uniform sampler2D noise_tex;
uniform sampler2D detail_normal : hint_normal;
uniform float noise_scale = 0.06;
uniform float normal_strength = 0.35;
uniform float wet_enabled = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, world_pos.xz * noise_scale).r;
	float n2 = texture(noise_tex, world_pos.xz * noise_scale * 5.0).r;
	vec3 col = mix(base_color, alt_color, smoothstep(0.3, 0.7, n));
	col *= 0.95 + 0.1 * n2;
	float shore = smoothstep(37.0, 40.8, length(world_pos.xz)) * wet_enabled;
	col = mix(col, col * 0.66, shore * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.45, shore);
	NORMAL_MAP = texture(detail_normal, world_pos.xz * noise_scale * 4.0).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
