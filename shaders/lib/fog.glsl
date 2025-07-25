#if !defined NETHER && !defined END
	uniform vec3 skyColorLinear;
#endif

uniform vec2 fogState;
uniform vec3 fogColor;
uniform int isEyeInWater;

float16_t pbr_fog(float dist) {
	// Beer–Lambert law https://discord.com/channels/237199950235041794/276979724922781697/612009520117448764
	return min(float16_t(1.0 - exp(-0.001 / fogState.y * dist)), float16_t(1.0));
}

float16_t edge_fog(vec3 pe) {
	immut float n_dist = (max(length(pe.xz), abs(pe.y)) + 1.0) / fogState.x;

	return min(float16_t(pow(n_dist, fogState.y)), float16_t(1.0));
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
				immut uvec2 texel_pos = gl_GlobalInvocationID.xy;
			#endif

			return mix(f16vec3(rand(fma(trunc(texel_pos * 0.25), vec2(4.0), frameTimeCounter.xx))), f16vec3(rand(floor(n_pe.xz * 1024.0 + frameTimeCounter * 1))) * f16vec3(0.05, 0.0, 0.05) * (float16_t(1.25) - float16_t(n_pe.y)), float16_t(0.99));
		}
	#else
		f16vec3 sky(float16_t sky_fog, vec3 n_pe, vec3 sun_dir) {
			f16vec3 color = mix(f16vec3(skyColorLinear), linear(f16vec3(fogColor)), sky_fog);

			#if SUN_BLOOM || SKY_BLOOM
				if (isEyeInWater == 0) {
					immut float proximity = dot(n_pe, sun_dir);

					immut float sun = max(0.0, proximity); // * skyState.y // make this only apply to edge fog, not pbr
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
