uniform float wetness;

#if SM && defined MC_SPECULAR_MAP
	uniform sampler2D specular;

	float16_t map_roughness(float16_t map) {
		float16_t roughness;

		#if SM_TYPE == 0 // linear roughness
			roughness = map;
		#elif SM_TYPE == 1 // perceptual roughness
			roughness = map * map;
		#else // perceptual smoothness
			immut float16_t perceptual_roughness = float16_t(1.0) - map;
			roughness = perceptual_roughness * perceptual_roughness;
		#endif

		return clamp(
			fma(roughness, float16_t(SM), float16_t(-0.25) * float16_t(wetness)),
			float16_t(0.089),
			float16_t(1.0)
		);
	}
#else
	float16_t gen_roughness(float16_t luminance, float16_t avg_luma) {
		immut float16_t roughness = fma(avg_luma - luminance * float16_t(2.0), float16_t(0.4), float16_t(0.6));

		return clamp(
			fma(float16_t(wetness), float16_t(-0.25), roughness),
			float16_t(0.089),
			float16_t(1.0)
		);
	}
#endif