shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
// Tropical water: shore-distance color (bright shallows near the island,
// deep blue out at sea), animated foam ring at the waterline, two scrolling
// normal layers, gentle vertex waves. Shore math is radial (the island is a
// circle at the origin) — no depth texture, so it's Metal-safe on macOS 13.

uniform vec3 shallow_color : source_color = vec3(0.32, 0.74, 0.72);
uniform vec3 deep_color : source_color = vec3(0.03, 0.26, 0.5);
uniform sampler2D wave_normal1 : hint_normal;
uniform sampler2D wave_normal2 : hint_normal;
uniform float wave_height = 0.1;
uniform float wave_speed = 0.9;
uniform float shore_radius = 41.0;
uniform float shallow_band = 13.0;
uniform float foam_band = 2.6;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.3 + TIME * wave_speed) * wave_height
			+ cos(wpos.z * 0.24 + TIME * wave_speed * 1.25) * wave_height
			+ sin((wpos.x + wpos.z) * 0.045 + TIME * 0.45) * 0.18;
}

void fragment() {
	float r = length(wpos.xz);
	float depth_blend = smoothstep(shore_radius, shore_radius + shallow_band, r);
	vec3 col = mix(shallow_color, deep_color, depth_blend);

	// Foam: a breathing ring at the waterline, broken up by noise.
	float breathe = sin(TIME * 0.9) * 0.5;
	float foam = 1.0 - smoothstep(0.0, foam_band + breathe, r - shore_radius + 1.2);
	float breakup = texture(wave_normal1, wpos.xz * 0.18 + vec2(TIME * 0.025)).r;
	foam *= 0.55 + 0.45 * breakup;
	col = mix(col, vec3(0.95, 0.98, 0.98), clamp(foam, 0.0, 1.0) * 0.85);

	ALBEDO = col;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = clamp(0.68 + fres * 0.28 + foam * 0.4, 0.0, 0.97);
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	vec3 n1 = texture(wave_normal1, wpos.xz * 0.06 + vec2(TIME * 0.015, TIME * 0.02)).rgb;
	vec3 n2 = texture(wave_normal2, wpos.xz * 0.11 - vec2(TIME * 0.02, TIME * 0.013)).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = 0.72;
}
