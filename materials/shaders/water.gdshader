shader_type spatial;
render_mode depth_draw_never, blend_mix, cull_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

uniform vec3 shallow_color: source_color;
uniform vec3 deep_color: source_color;
uniform float clarity = 1.0;
uniform float wave_speed = 1.0;
uniform float wave_strength = 1.0;
uniform sampler2D normal_map;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.5 + TIME * wave_speed) * wave_strength;
	VERTEX.y += sin(VERTEX.z * 0.4 + TIME * wave_speed * 0.8) * wave_strength * 0.5;
}

void fragment() {
	float raw_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	
	vec4 terrain_view = (INV_PROJECTION_MATRIX * vec4(vec4(SCREEN_UV*2.0-1.0, raw_depth,1.0)));
	terrain_view /= terrain_view.w;
	float terrain_depth = -terrain_view.z;
	
	vec4 water_view = (INV_PROJECTION_MATRIX * vec4(vec4(SCREEN_UV*2.0-1.0, FRAGCOORD.z,1.0)));
	water_view /= water_view.w;
	float water_depth = -water_view.z;
	
	float thickness = terrain_depth - water_depth;
	float depth_factor = exp(-thickness * clarity);
	depth_factor = min(depth_factor, 1.0);
	vec3 normal_a = texture(normal_map, UV*4.0 + TIME/10.0).rgb * 2.0 - 1.0;
	vec2 refract_offset = normal_a.xy * 0.05;
	
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV + refract_offset);
	
	ALBEDO = mix(deep_color, shallow_color, depth_factor);
	ALBEDO = mix(ALBEDO, screen.rgb, depth_factor);
	
	ALBEDO = clamp(ALBEDO + step(-0.4, -thickness), vec3(0.0), vec3(1.0));
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ROUGHNESS = 0.3;
	NORMAL_MAP = texture(normal_map, UV*4.0 + TIME/10.0).rgb;
}