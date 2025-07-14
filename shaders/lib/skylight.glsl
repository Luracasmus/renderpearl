#ifdef END
	f16vec3 skylight() {
		return f16vec3(0.19, 0.1, 0.19);
	}
#else
	uniform vec3 skyState;

	f16vec3 skylight() {
		immut f16vec3 sky_state = f16vec3(skyState);

		const float16_t moonlight = float16_t(0.0);
		const float16_t sunrise = float16_t(0.05);
		const float16_t morning = float16_t(0.3);
		const float16_t zenith = float16_t(1.0);

		// todo!() check scales at: https://www.wikiwand.com/en/articles/Daylight#Intensity_in_different_conditions
		immut f16vec3 col_moonlight = f16vec3(0.69, 0.76, 0.99) * float16_t(0.01) * sky_state.z;
		const f16vec3 col_sunrise = f16vec3(0.89, 0.78, 0.31) * float16_t(0.25);
		const f16vec3 col_morning = f16vec3(0.92, 0.93, 0.55);
		const f16vec3 col_zenith = f16vec3(0.93, 0.95, 0.65); // f16vec3(0.99, 0.99, 0.91);

		const f16vec3 col_overcast = f16vec3(0.17, 0.19, 0.25);

		return float16_t(DIR_SL) * mix(
			col_moonlight,
			mix(
				col_sunrise,
				mix(
					col_morning,
					col_zenith,
					smoothstep(morning, zenith, sky_state.y)
				),
				smoothstep(sunrise, morning, sky_state.y)
			),
			smoothstep(moonlight, sunrise, sky_state.y)
		) * mix(f16vec3(1.0), col_overcast, sky_state.x);
	}
#endif
