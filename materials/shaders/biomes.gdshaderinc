int get_biome_index(float color_val) {
	int humidity = int(color_val*255.0)%16;
	int temperature = int(color_val*255.0)/16;
	int biome_index = (humidity / 8) + (temperature / 4)*2;
	return biome_index;
}