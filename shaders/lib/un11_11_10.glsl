f16vec3 unpack_un11_11_10(uint data) {
	return f16vec3(
		data & 2047u,
		bitfieldExtract(data, 11, 11),
		bitfieldExtract(data, 22, 10)
	) / f16vec3(2047.0, 2047.0, 1023.0);
}

uint pack_un11_11_10(vec3 color) {
	uvec3 scaled_color = uvec3(fma(color, vec3(2047.0, 2047.0, 1023.0), vec3(0.5)));
	return bitfieldInsert(bitfieldInsert(scaled_color.r, scaled_color.g, 11, 11), scaled_color.b, 22, 10);
}