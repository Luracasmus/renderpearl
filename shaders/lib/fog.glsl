#if !defined NETHER && !defined END
	uniform vec3 skyColorLinear;
#endif

uniform float far, fogEnd, fogStart;
uniform vec3 fogColor;
uniform int isEyeInWater;

float16_t linear_step(float16_t edge0, float16_t edge1, float16_t x) {
	return saturate((x - edge0) / (edge1 - edge0));
}

float16_t vanilla_fog(vec3 pe) {
	immut float16_t far_f16 = float16_t(far);

	return max(
		linear_step(float16_t(fogStart), float16_t(fogEnd), float16_t(length(pe))), // Spherical environment fog.
		linear_step(
			far_f16 - clamp(float16_t(0.1) * far_f16, float16_t(4.0), float16_t(64.0)),
			far_f16,
			max(float16_t(length(pe.xz)), abs(float16_t(pe.y)))
		) // Cylidrical border fog.
	);
}

float16_t sky_fog(float16_t height) {
	height = max(height, float16_t(0.0));

	return min(float16_t(0.25) / fma(height, height, float16_t(0.25)) + float16_t(isEyeInWater), float16_t(1.0));
}

#ifndef NETHER
	#ifdef END
		f16vec3 sky(vec3 n_pe) {
			#ifdef SKY_FSH
				immut vec2 texel_pos = gl_FragCoord.xy;
			#else
				immut vec2 texel_pos = vec2(gl_GlobalInvocationID.xy);
			#endif

			return mix(
				f16vec3(rand(fma(trunc(texel_pos * 0.25), vec2(4.0), frameTimeCounter.xx))),
				f16vec3(rand(floor(n_pe.xz * 1024.0 + frameTimeCounter * 1))) * f16vec3(0.05, 0.0, 0.05) * (float16_t(1.25) - float16_t(n_pe.y)),
				float16_t(0.99)
			) * fma(float16_t(endFlashIntensity), float16_t(1.5), float16_t(0.5));
		}
	#else
		f16vec3 sky(float16_t sky_fog, vec3 n_pe, vec3 sun_dir) {
			f16vec3 color = mix(f16vec3(skyColorLinear), linear(f16vec3(fogColor)) * float16_t(2.0), sky_fog);

			#if SUN_BLOOM || SKY_BLOOM
				if (isEyeInWater == 0) {
					immut float proximity = dot(n_pe, sun_dir);

					immut float sun = max(0.0, proximity); // * skyState.y // TODO: Make this only apply to edge fog, not PBR.
					immut float moon = max(0.0, -proximity) * float16_t(skyState.z) * float16_t(0.2); // * (1.0 - skyState.y)

					immut float16_t day = float16_t(skyState.y);

					color = fma(
						min(
							day + float16_t(0.5),
							float16_t(1.0)) * f16vec3(float16_t(SUN_BLOOM) * float16_t(pow(sun, 256.0)) + day * float16_t(SKY_BLOOM) * pow(float16_t(sun), float16_t(3.0))
						),
						float16_t(0.15) * skylight(),
						color
					);

					color = fma(f16vec3(float16_t(SUN_BLOOM) * float16_t(pow(moon, 256.0)) + float16_t(SKY_BLOOM) * pow(float16_t(moon), float16_t(3.0))), f16vec3(0.0104, 0.0112, 0.0152), color);
				}
			#endif

			return color;
		}
	#endif
#endif
