uniform float day;
uniform vec3 cameraPositionFract;

#ifdef LIGHT_LEVELS
	#include "/lib/llv.glsl"
#endif

#include "/lib/brdf.glsl"
#include "/lib/skylight.glsl"

// Slightly less cool version of the lighting done in `deferred1_a.csh`, adapted to work in vertex shaders.
// TODO: Apply hand light.
f16vec3 indexed_block_light(vec3 pe, f16vec3 w_face_normal, float16_t ao) {
	immut float16_t ind_bl = float16_t(IND_BL) * ao;

	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	f16vec2 light = norm_uv2();

	#ifdef LIGHT_LEVELS
		f16vec3 block_light = visualize_ll(light.x);
	#else
		f16vec3 block_light = light.x * f16vec3(BL_FALLBACK_R, BL_FALLBACK_G, BL_FALLBACK_B);
	#endif

	if (light.x > float16_t(0.0) && chebyshev_dist < float16_t(LL_DIST)) {
		immut vec3 offset = ((-255.5 - cameraPositionFract - mvInv3) + subgroupBroadcastFirst(ll.offset)) - pe;

		f16vec3 diffuse = f16vec3(0.0);

		immut uint16_t index_len = uint16_t(subgroupBroadcastFirst(ll.len));
		for (uint16_t i = uint16_t(0u); i < index_len; ++i) {
			immut uint light_data = ll.data[i];

			immut f16vec3 w_rel_light = f16vec3(vec3(
				light_data & 511u,
				bitfieldExtract(light_data, 9, 9),
				bitfieldExtract(light_data, 18, 9)
			) + offset);

			immut float16_t intensity = float16_t(bitfieldExtract(light_data, 27, 4));
			immut float16_t mhtn_dist = dot(abs(w_rel_light), f16vec3(1.0));

			if (mhtn_dist < intensity + float16_t(0.5)) {
				immut uint16_t light_color = ll.color[i];

				immut float16_t sq_dist_light = dot(w_rel_light, w_rel_light);
				immut f16vec3 n_w_rel_light = w_rel_light * inversesqrt(sq_dist_light);

				// Make falloff start a block away of the light source when the "wide" flag (most significant bit) is set.
				immut float16_t falloff = float16_t(1.0) / (
					light_data >= 0x80000000u ? max(sq_dist_light - float16_t(1.0), float16_t(1.0)) : sq_dist_light
				);

				immut float16_t light_level = intensity - mhtn_dist + float16_t(0.5);
				float16_t brightness = intensity * falloff;
				brightness *= smoothstep(float16_t(0.0), float16_t(LL_FALLOFF_MARGIN), light_level);
				brightness /= min(light_level, float16_t(15.0)) * float16_t(1.0/15.0); // Compensate for multiplication with `light.x` later on, in order to make the falloff follow the inverse square law as much as possible.
				brightness = min(brightness, float16_t(48.0)); // Prevent `float16_t` overflow later on.

				#ifdef INT16
					immut f16vec3 illum = brightness * f16vec3(
						(light_color >> uint16_t(6u)) & uint16_t(31u),
						light_color & uint16_t(63u),
						(light_color >> uint16_t(11u))
					);
				#else
					immut f16vec3 illum = brightness * f16vec3(
						bitfieldExtract(uint(light_color), 6, 5),
						light_color & uint16_t(63u),
						(light_color >> uint16_t(11u))
					);
				#endif

				immut float16_t face_n_dot_l = dot(w_face_normal, n_w_rel_light);

				float16_t light_diffuse = ind_bl; // Very fake GI.

				if (face_n_dot_l > float16_t(0.0)) {
					light_diffuse += brdf(face_n_dot_l, w_face_normal, normalize(f16vec3(pe)), n_w_rel_light, float16_t(1.0)).y;
				}

				diffuse = fma(light_diffuse.xxx, illum, diffuse);
			}
		}

		// Undo the multiplication from packing light color and brightness.
		const vec3 packing_scale = vec3(15u * uvec3(31u, 63u, 31u));
		immut f16vec3 new_light = f16vec3(float(DIR_BL * 3) / packing_scale) * light.x * diffuse;

		block_light = mix(new_light, block_light, smoothstep(float16_t(LL_DIST - 15), float16_t(LL_DIST), chebyshev_dist));
	}

	#ifdef LIGHT_LEVELS
		const float16_t ind_sky = float16_t(0.0);
	#else
		#ifdef NETHER
			const f16vec3 ind_sky = f16vec3(0.3, 0.15, 0.2);
		#elif defined END
			const f16vec3 ind_sky = f16vec3(0.15, 0.075, 0.2);
		#else
			immut float16_t ind_sky = luminance(skylight()) / float16_t(DIR_SL) * smoothstep(float16_t(0.0), float16_t(1.0), light.y);
		#endif
	#endif

	return fma(
		fma(
			f16vec3(ind_sky),
			f16vec3(IND_SL),
			f16vec3(AMBIENT * 0.1)
		),
		ao.xxx,
		block_light
	);
}
