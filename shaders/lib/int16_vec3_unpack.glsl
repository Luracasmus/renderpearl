// Fast function to unpack three values from an int16_t, utilizing packed math to possibly execute in just two cycles if `size_01` is compile-time constant

// todo!() use when Iris updates glsl-transformer to 2.0.2
u16vec3 unpack_u16vec3_from_uint16_t(
	uint16_t data,
	u16vec2 size_01 // Sizes in bits of the first two components. Must add up to less than 16. Should be constant for good performance
) {
	// u16vec2 >> u16vec2 is one VOP3P instruction on RDNA4
	immut u16vec2 shifted_12 = data >> u16vec2(
		size_01.x,
		size_01.x + size_01.y  // this can be calculated at compile time if `size_01` is constant
	);

	// min(i16vec2, i16vec2) is one VOP3P instruction on RDNA4
	immut u16vec2 masked_01 = min(
		u16vec2(data, shifted_12.x),
		uint16_t(1u) << size_01 // this can be calculated at compile time if `size_01` is constant
	);

	return u16vec3(masked_01, shifted_12.y);
}
