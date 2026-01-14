// Ambient light and Indirect sky light.
f16vec3 non_block_light(f16vec3 sky_light_color, float16_t sky_light_level) {
	#ifdef LIGHT_LEVELS
		const float16_t color = float16_t(0.0);
	#else
		#ifdef NETHER
			const f16vec3 color = f16vec3(0.3, 0.15, 0.2);
		#elif defined END
			const f16vec3 color = f16vec3(0.15, 0.075, 0.2);
		#else
			immut float16_t color = luminance(sky_light_color) / float16_t(DIR_SL) * smoothstep(float16_t(0.0), float16_t(1.0), sky_light_level);
		#endif
	#endif

	return fma(color, f16vec3(IND_SL), f16vec3(AMBIENT * 0.1)));
}
