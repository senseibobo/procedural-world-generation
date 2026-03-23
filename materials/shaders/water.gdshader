shader_type spatial;
render_mode depth_draw_never, blend_mix, cull_disabled;
#include "biomes.gdshaderinc"


uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

varying flat vec3 v_biome_color;
uniform sampler2D biome_deep_colors: filter_nearest;
uniform sampler2D biome_shallow_colors: filter_nearest;
uniform float clarity = 1.0;
uniform float wave_speed = 1.0;
uniform float wave_strength = 1.0;
uniform sampler2D normal_map;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).rgb;
	VERTEX.y += sin(world_pos.x * 0.5 + TIME * wave_speed) * wave_strength;
	VERTEX.y += sin(world_pos.z * 0.4 + TIME * wave_speed * 0.8) * wave_strength * 0.5;
	v_biome_color = COLOR.rgb;
}

void fragment() {
	float raw_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	
	vec4 terrain_view = (INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0, raw_depth,1.0));
	terrain_view /= terrain_view.w;
	float terrain_depth = -terrain_view.z;
	
	vec4 water_view = (INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0, FRAGCOORD.z,1.0));
	water_view /= water_view.w;
	float water_depth = -water_view.z;
	
	float thickness = terrain_depth - water_depth;
	float depth_factor = exp(-thickness * clarity);
	depth_factor = min(depth_factor, 1.0);
	
	int biome1_id = get_biome_index(v_biome_color.r);
	int biome2_id = get_biome_index(v_biome_color.g);
	float blend = v_biome_color.b;//clamp(v_biome_color.b-0.9,0.0,0.1)*10.0-0.5;
	vec3 biome1_deep_color = texture(biome_deep_colors, vec2(float(biome1_id)/8.0,0.0)).rgb;
	vec3 biome1_shallow_color = texture(biome_shallow_colors, vec2(float(biome1_id)/8.0,0.0)).rgb;
	vec3 biome2_deep_color = texture(biome_deep_colors, vec2(float(biome2_id)/8.0,0.0)).rgb;
	vec3 biome2_shallow_color = texture(biome_shallow_colors, vec2(float(biome2_id)/8.0,0.0)).rgb;
	vec3 deep_color = mix(biome1_deep_color, biome2_deep_color, blend);
	vec3 shallow_color = mix(biome1_shallow_color, biome2_shallow_color, blend);
	
	ALBEDO = mix(deep_color, shallow_color, depth_factor);
	ALPHA = 1.0-depth_factor;
	
	ALBEDO = clamp(ALBEDO + step(-0.4, -thickness), vec3(0.0), vec3(1.0));
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ROUGHNESS = 0.3;
	NORMAL_MAP = texture(normal_map, UV/4.0 + TIME/10.0).rgb;
}