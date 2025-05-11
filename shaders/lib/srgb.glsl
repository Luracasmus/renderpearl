/*
	float linear(float srgb) {
		return srgb <= 0.04045 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4);
	}

	float srgb(float linear) {
		return linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1.0/2.4) - 0.055;
	}
*/

vec3 linear(vec3 srgb) {
	return mix(
		pow(fma(srgb, vec3(1.0/1.055), vec3(0.055/1.055)), vec3(2.4)),
		srgb / 12.92,
		lessThanEqual(srgb, vec3(0.04045))
	);
}

vec3 srgb(vec3 linear) {
	return mix(
		fma(pow(linear, vec3(1.0/2.4)), vec3(1.055), vec3(-0.055)),
		linear * 12.92,
		lessThanEqual(linear, vec3(0.0031308))
	);
}

#ifdef FLOAT16
	f16vec3 linear(f16vec3 srgb) {
		return mix(
			pow(fma(srgb, f16vec3(1.0/1.055), f16vec3(0.055/1.055)), f16vec3(2.4)),
			float16_t(1.0/12.92) * srgb,
			lessThanEqual(srgb, f16vec3(0.04045))
		);
	}

	f16vec3 srgb(f16vec3 linear) {
		return mix(
			fma(pow(linear, f16vec3(1.0/2.4)), f16vec3(1.055), f16vec3(-0.055)),
			float16_t(12.92) * linear,
			lessThanEqual(linear, f16vec3(0.0031308))
		);
	}
#endif