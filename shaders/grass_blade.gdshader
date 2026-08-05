shader_type spatial;
render_mode cull_disabled, specular_disabled, shadows_disabled;
// Instanced grass blades. Each blade bends in the breeze with a phase
// taken from its instance origin, so the meadow ripples instead of
// swaying in lockstep. Instance COLOR carries the per-blade tint.

uniform float sway_amp = 0.05;
uniform float sway_speed = 1.7;
uniform vec3 tint_a : source_color = vec3(0.4, 0.74, 0.28);
uniform vec3 tint_b : source_color = vec3(0.62, 0.88, 0.36);
uniform vec3 tint_dry : source_color = vec3(0.82, 0.76, 0.4);

varying vec3 blade_tint;

void vertex() {
	vec2 origin = MODEL_MATRIX[3].xz;
	float phase = origin.x * 0.9 + origin.y * 0.7;
	float bend = sin(TIME * sway_speed + phase) + 0.35 * sin(TIME * sway_speed * 2.3 + phase * 1.7);
	VERTEX.x += bend * sway_amp * VERTEX.y * 3.0;
	// Per-blade tint from a hash of the instance origin — no instance
	// color data needed, so it can't silently fall back to white.
	float h = fract(sin(dot(origin, vec2(12.9898, 78.233))) * 43758.5453);
	blade_tint = mix(tint_a, tint_b, h);
	if (h > 0.95) {
		blade_tint = tint_dry;
	}
}

void fragment() {
	ALBEDO = blade_tint;
	ROUGHNESS = 1.0;
}
