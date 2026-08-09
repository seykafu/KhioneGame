shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// NOTE: blend_add on big sky quads intermittently corrupted whole frames
// to darkness on this macOS 13 Metal driver (same family as the omni
// light and reflection probe bugs). blend_mix with alpha is stable.
// The northern lights: additive curtains on big quads over the north sky.
// Scrolling noise shapes the curtain's lower hem and its vertical rays;
// color runs green at the hem through teal to a violet crown. No depth
// textures, no lights: Metal-safe.

uniform sampler2D band_noise;
uniform float speed = 0.02;
uniform float strength = 1.0;

void fragment() {
	float hgt = 1.0 - UV.y;  // 0 at the curtain's hem, 1 at its crown
	float n = texture(band_noise, vec2(UV.x * 3.2 + TIME * speed, 0.35 - TIME * speed * 0.5)).r;
	// The hem itself wanders with the noise, and the curtain thins fast
	// above it: real curtains are ragged, not rectangular.
	float hem = 0.08 + n * 0.22;
	float curtain = smoothstep(hem, hem + 0.1, hgt)
			* (1.0 - smoothstep(hem + 0.12, hem + 0.5 + n * 0.25, hgt));
	// Fade the quad's side edges away entirely.
	float edge = smoothstep(0.0, 0.18, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
	float rays = 0.3 + 0.7 * texture(band_noise,
			vec2(UV.x * 9.0 + n * 0.8 + TIME * speed * 1.7, 0.62)).r;
	float flicker = 0.85 + 0.15 * sin(TIME * 0.7 + UV.x * 9.0);
	vec3 col = mix(vec3(0.15, 0.95, 0.5), vec3(0.15, 0.55, 0.85), clamp(hgt * 1.5, 0.0, 1.0));
	col = mix(col, vec3(0.55, 0.3, 0.85), smoothstep(0.45, 0.9, hgt));
	float lum = curtain * edge * rays * flicker * strength;
	ALBEDO = col * 1.6;
	ALPHA = clamp(lum, 0.0, 0.8);
}
