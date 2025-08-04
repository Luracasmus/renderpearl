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

		return clamp(
			fma(float16_t(wetness), float16_t(-0.25), roughness),
			float16_t(0.089),
			float16_t(1.0)
		);
	}
#else
	// https://www.wikiwand.com/en/articles/Smoothstep
	/*
		float16_t smootherstep(float16_t edge0, float16_t edge1, float16_t x) {
			x = saturate((x - edge0) / (edge1 - edge0));

			return x*x*x * fma(fma(x, float16_t(6.0), float16_t(-15.0)), x, float16_t(10.0));
		}
	*/

	float16_t smoothererstep(float16_t edge0, float16_t edge1, float16_t x) {
		x = saturate((x - edge0) / (edge1 - edge0));

		return x*x*x*x * fma(
			fma(
				fma(x, float16_t(-20.0), float16_t(70.0)),
				x, float16_t(-84.0)
			),
			x, float16_t(35.0)
		);
	}

	float16_t gen_roughness(float16_t luminance, float16_t avg_luma) {
		// immut float16_t roughness = fma((avg_luma - luminance) * float16_t(4.0), float16_t(0.4), float16_t(0.6));

		immut float16_t diff = avg_luma - luminance;
		// immut float16_t roughness = sqrt(fma(diff*diff*diff, float16_t(0.5), float16_t(0.5)));
		// immut float16_t roughness = pow(fma(pow(diff, float16_t(1.0/3.0)), float16_t(0.5), float16_t(0.5)), float16_t(0.1));
		// immut float16_t roughness = sqrt(fma(
		// 	inversesqrt(inversesqrt(smootherstep(float16_t(0.0), float16_t(1.0), diff))),
		// 	float16_t(1.0 - 0.089),
		// 	float16_t(0.089)
		// ));
		immut float16_t roughness = fma(
			smoothererstep(float16_t(0.0), float16_t(1.0), smoothererstep(float16_t(-1.0), float16_t(1.0), diff)),
			float16_t(1.0 - 0.089),
			float16_t(0.089)
		); // magnifikt

		return clamp(
			fma(float16_t(wetness), float16_t(-0.25), roughness),
			float16_t(0.089),
			float16_t(1.0)
		);
	}
#endif
