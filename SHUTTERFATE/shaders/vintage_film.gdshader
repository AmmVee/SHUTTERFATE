shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float grain_amount : hint_range(0.0, 1.0) = 0.06;
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 1.5;
uniform float vignette_intensity : hint_range(0.0, 3.0) = 0.6;
uniform float desaturation : hint_range(0.0, 1.0) = 0.15;
uniform float aberration_offset : hint_range(0.0, 0.02) = 0.002;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.03;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	float r = texture(SCREEN_TEXTURE, uv + vec2(aberration_offset, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(aberration_offset, 0.0)).b;
	vec3 color = vec3(r, g, b);

	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray), desaturation);

	color.r = mix(color.r, color.r * 1.08, 0.2);
	color.b = mix(color.b, color.b * 0.95, 0.2);

	vec2 dist = uv - 0.5;
	float vignette = 1.0 - dot(dist, dist) * vignette_intensity;
	color *= clamp(vignette, 0.5, 1.0);

	float noise = random(uv + fract(TIME * 0.1)) * grain_amount;
	color += noise - grain_amount * 0.5;

	float scanline = sin(uv.y * 600.0) * scanline_intensity;
	color -= scanline;

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
