// Ambient light and Indirect sky light.
f16vec3 non_block_light(f16vec3 sky_light_color, float16_t sky_light_level) {
	#ifdef LIGHT_LEVELS
		const float16_t color = float16_t(0.0);
	#else
		#ifdef NETHER
			const f16vec3 color = f16vec3(vec3(0.9, 0.45, 0.6) * lumi_global_nether / lumi_zenith);
		#elif defined END
			const f16vec3 color = f16vec3(vec3(0.65, 0.325, 1.0) * lumi_end / lumi_zenith);
		#else
			immut float16_t color = luminance(sky_light_color) / float16_t(lumi_zenith) * smoothstep(float16_t(0.0), float16_t(1.0), sky_light_level);
		#endif
	#endif

	return fma(f16vec3(color), f16vec3(lumi_ind_daylight), f16vec3(lumi_ambient));
}
