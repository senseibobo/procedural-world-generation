shader_type spatial;


uniform sampler2DArray biome_textures;
uniform sampler2D rock_texture;


varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;
uniform float uv1_blend_sharpness = 0.1;
varying flat vec3 v_biome_color;

uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);



vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

vec4 triplanar_texture(sampler2DArray p_sampler, vec3 p_weights, vec3 p_triplanar_pos, float w) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, vec3(p_triplanar_pos.xy,w)) * p_weights.z;
	samp += texture(p_sampler, vec3(p_triplanar_pos.xz,w)) * p_weights.y;
	samp += texture(p_sampler, vec3(p_triplanar_pos.zy * vec2(-1.0, 1.0),w)) * p_weights.x;
	return samp;
}

int get_biome_index(float color_val) {
	int humidity = int(color_val*255.0)%16;
	int temperature = int(color_val*255.0)/16;
	int biome_index = (humidity / 8) + (temperature / 4)*2;
	return biome_index;
}

void vertex() {
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	uv1_power_normal = pow(abs(normal), vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * uv1_scale + uv1_offset;
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
	v_biome_color = COLOR.rgb;
}

void fragment() {
	vec3 normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).rgb;
	vec3 rock_sample = triplanar_texture(rock_texture, uv1_power_normal, uv1_triplanar_pos).rgb;
	float n = dot(normal, vec3(0.0,1.0,0.0));
	
    int biome1_index = get_biome_index(v_biome_color.r);
    int biome2_index = get_biome_index(v_biome_color.g);
	float blend = v_biome_color.b;
	
	vec3 biome1_grass_sample = triplanar_texture(biome_textures, uv1_power_normal, uv1_triplanar_pos, float(biome1_index)).rgb;
	vec3 biome2_grass_sample = triplanar_texture(biome_textures, uv1_power_normal, uv1_triplanar_pos, float(biome2_index)).rgb;
	
	vec3 biome_grass_sample = mix(biome1_grass_sample, biome2_grass_sample, blend);
	
	//ALBEDO = v_biome_color;
	ALBEDO = mix(rock_sample, biome_grass_sample, smoothstep(0.6, 0.8, n));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
