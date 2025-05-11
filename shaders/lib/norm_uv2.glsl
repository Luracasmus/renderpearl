in ivec2 vaUV2;

// vaUV2 scaled to 0..=1
// with sky light adjusted based on day time
// (not great to be doing it here tho, but we need to avoid adjusting AMBIENT based on daytime to not make caves vary in brigtness)
// todo!() fix some other way
f16vec2 norm_uv2() {
	/*
	f16vec2 norm_light_level = f16vec2((
		mat4(0.00390625, 0.0, 0.0, 0.0, 0.0, 0.00390625, 0.0, 0.0, 0.0, 0.0, 0.00390625, 0.0, 0.03125, 0.03125, 0.03125, 1.0) * vec4(vaUV2, 0.0, 1.0)
	).xy);

	return f16vec2((norm_light_level * 33.05 / 32.0) - (1.05 / 32.0));
	*/

	// return fma(f16vec2(vaUV2), f16vec2(1.0/240.0), f16vec2(-1.0/30.0));

	f16vec2 norm_light_level = fma(f16vec2(vaUV2), f16vec2(1.0/232.0), f16vec2(-1.0/29.0));
	norm_light_level.y *= clamp(float16_t(day) * float16_t(10.0), float16_t(0.25), float16_t(1.0));

	return norm_light_level;
}
