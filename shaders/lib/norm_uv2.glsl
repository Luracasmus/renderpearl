in ivec2 vaUV2;

// vaUV2 scaled to 0..=1
f16vec2 norm_uv2() {
	/*
		f16vec2 norm_light_level = f16vec2((
			mat4(0.00390625, 0.0, 0.0, 0.0, 0.0, 0.00390625, 0.0, 0.0, 0.0, 0.0, 0.00390625, 0.0, 0.03125, 0.03125, 0.03125, 1.0) * vec4(vaUV2, 0.0, 1.0)
		).xy);

		return f16vec2((norm_light_level * 33.05 / 32.0) - (1.05 / 32.0));
	*/

	// return fma(f16vec2(vaUV2), f16vec2(1.0/240.0), f16vec2(-1.0/30.0));

	return fma(f16vec2(vaUV2), f16vec2(1.0/232.0), f16vec2(-1.0/29.0));
}
