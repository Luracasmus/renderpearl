f16vec3 visualize_ll(float16_t light) {
	immut float16_t light_level = light * float16_t(15.0);

	return mix(
		f16vec3(0.25, 0.0, 0.0),
		mix(
			f16vec3(0.5, 0.5, 0.0),
			mix(
				f16vec3(0.75, 0.5, 0.0),
				mix(
					f16vec3(1.0, 0.75, 0.0),
					f16vec3(1.0, 1.0, 1.0),
					smoothstep(float16_t(8.0), float16_t(15.0), light_level)
				),
				smoothstep(float16_t(8.0), float16_t(11.0), light_level)
			),
			smoothstep(float16_t(1.0), float16_t(7.0), light_level)
		),
		smoothstep(float16_t(0.0), float16_t(1.0), light_level)
	);
}