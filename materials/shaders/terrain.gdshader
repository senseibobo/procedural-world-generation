shader_type spatial;

void vertex() {
	//vec3 world_pos = ((MODEL_MATRIX) * vec4(VERTEX, 0.0)).rgb;
	//COLOR.r = pow(world_pos.y/10.0,0.5);
}

void fragment() {
	//ALBEDO = COLOR.rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
