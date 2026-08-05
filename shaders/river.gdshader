shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;
// The creek: a ribbon draped over the terrain. Flow scrolls along the
// ribbon's U axis; foam appears where the ribbon is steep (the waterfall
// chute) and along the banks. No depth texture — Metal-safe on macOS 13.

uniform vec3 col_water : source_color = vec3(0.36, 0.72, 0.7);
uniform vec3 col_foam : source_color = vec3(0.95, 0.98, 0.98);
uniform sampler2D flow_noise;
uniform float flow_speed = 0.55;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float flow = texture(flow_noise, vec2(UV.x - TIME * flow_speed, UV.y * 0.8)).r;
	float flow2 = texture(flow_noise, vec2(UV.x * 2.3 - TIME * flow_speed * 1.6, UV.y * 1.7 + 0.37)).r;
	vec3 col = col_water * (0.82 + 0.28 * flow);
	// Steep stretches (the falls) and the banks churn white.
	float steep = 1.0 - smoothstep(0.55, 0.88, abs(wnorm.y));
	float edge = smoothstep(0.41, 0.5, abs(UV.y - 0.5));
	float churn = clamp(max(steep, edge * 0.6), 0.0, 1.0) * (0.45 + 0.55 * flow2);
	col = mix(col, col_foam, churn);
	ALBEDO = col;
	ALPHA = clamp(0.78 + churn * 0.2, 0.0, 0.95);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
