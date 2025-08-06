uniform float wetness;

#if defined SM && defined MC_SPECULAR_MAP
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

		return max(
			fma(float16_t(wetness), float16_t(-0.25), roughness),
			float16_t(0.089)
		);
	}
#else
	float16_t gen_roughness(float16_t luminance, float16_t avg_luma) {
		const float16_t contrast = float16_t(-14.0); // todo!() make this configurable

		immut float16_t diff = avg_luma - luminance;

		// Thanks to Builderb0y (https://github.com/Builderb0y) for converting this to a logistic function
		// https://discord.com/channels/237199950235041794/1401709875171688528/1401981189954342982 (shaderLABS)
		immut float16_t roughness = float16_t(0.911) / (exp2(contrast * diff) + float16_t(1.0)) + float16_t(0.089); // magnifikt

		return max(
			fma(float16_t(wetness), float16_t(-0.25), roughness),
			float16_t(0.089)
		);
	}
#endif
