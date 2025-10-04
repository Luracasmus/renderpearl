#ifdef INT16
	// Functions for packing and unpacking three values from a `uint16_t`, optimized to execute in just 4 and 2 instructions respectively on RDNA4.
	// TODO: use when Iris updates glsl-transformer to 2.0.2

	u16vec3 u16_unpack3(
		uint16_t data,
		u16vec2 size_01 // Sizes in bits of the first two components. Must add up to less than 16. Should be compile time constant for optimal performance
	) {
		// V_PK_LSHRREV_B16
		immut u16vec2 shifted_12 = data >> u16vec2(
			size_01.x,
			size_01.x + size_01.y  // This can be calculated at compile time if `size_01` is constant.
		);

		// V_PK_MIN_U16
		immut u16vec2 masked_01 = min(
			u16vec2(data, shifted_12.x),
			uint16_t(1u) << size_01 // This can be calculated at compile time if `size_01` is constant.
		);

		return u16vec3(masked_01, shifted_12.y);
	}

	uint16_t u16_pack3(
		u16vec3 data,
		u16vec2 size_01 // Sizes in bits of the first two components. Must add up to less than 16. Should be compile time constant for optimal performance.
	) {
		// V_PK_MIN_U16
		immut u16vec2 masked_01 = min(
			u16vec2(data.x, data.y),
			uint16_t(1u) << size_01 // This can be calculated at compile time if `size_01` is constant.
		);

		// V_PK_LSHLREV_B16
		immut u16vec2 shifted_12 = data.z << u16vec2(
			size_01.x,
			size_01.x + size_01.y  // This can be calculated at compile time if `size_01` is constant.
		);

		// V_AND_B16` x2
		return masked_01.x | shifted_12.x | shifted_12.y;
	}
#else
	// TODO: add fallbacks using BFI/BFE
#endif
