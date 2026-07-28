shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec3 shallow_color: source_color = vec3(0.25, 0.62, 0.72);
uniform vec3 deep_color: source_color = vec3(0.05, 0.3, 0.55);
uniform float wave_height = 0.12;
uniform float wave_speed = 1.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 0.35 + TIME * wave_speed) * wave_height
			+ cos(wp.z * 0.28 + TIME * wave_speed * 1.3) * wave_height;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color, shallow_color, fresnel * 0.7);
	ALPHA = 0.82;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
