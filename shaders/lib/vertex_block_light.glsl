uniform float day;
uniform vec3 cameraPositionFract;

#ifdef LIGHT_LEVELS
	#include "/lib/llv.glsl"
#endif

readonly
#include "/buf/index.glsl"

#include "/lib/luminance.glsl"
#include "/lib/brdf.glsl"
#include "/lib/norm_uv2.glsl"

// slightly less cool version of the lighting done in deferred1_a.csh, adapted to work in vertex shaders
f16vec3 indexed_block_light(vec3 pe, f16vec3 w_face_normal) {
	f16vec2 light = norm_uv2();
	light.y = min(float16_t(1.0), light.y + float16_t(AMBIENT) * float16_t(vaColor.a));

	#ifdef LIGHT_LEVELS
		f16vec3 block_light = visualize_ll(light.x);
	#else
		f16vec3 block_light = light.x*light.x * f16vec3(1.2, 1.2, 1.0);
	#endif

	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	if (light.x > float16_t(0.0) && chebyshev_dist < float16_t(INDEX_DIST)) {
		immut vec3 offset = -255.5 - cameraPositionFract - gbufferModelViewInverse[3].xyz + index.offset - pe;

		f16vec3 diffuse = f16vec3(0.0);

		immut uint16_t index_len = uint16_t(index.len);
		for (uint16_t i = uint16_t(0u); i < index_len; ++i) {
			immut uint light_data = index.data[i];

			immut f16vec3 w_rel_light = f16vec3(vec3(
				light_data & 511u,
				bitfieldExtract(light_data, 9, 9),
				bitfieldExtract(light_data, 18, 9)
			) + offset);

			immut float16_t intensity = float16_t(bitfieldExtract(light_data, 27, 4));
			immut float16_t mhtn_dist = dot(abs(w_rel_light), f16vec3(1.0));

			if (mhtn_dist <= intensity) {
				immut uint16_t light_color = index.color[i];

				immut float16_t sq_dist_light = dot(w_rel_light, w_rel_light);
				immut float16_t rcp_dist_light = inversesqrt(sq_dist_light);
				immut float16_t face_n_dot_l = dot(w_face_normal, w_rel_light * rcp_dist_light);

				immut float16_t falloff = light_data >= 0x80000000u ? rcp_dist_light : float16_t(1.0) / sq_dist_light;
				// use linear falloff instead of inverse square law when the "wide" flag is set

				immut float16_t brightness = min(min(intensity - mhtn_dist, float16_t(1.0)) * intensity * falloff, float16_t(48.0));

				immut f16vec3 illum = brightness * f16vec3(
					bitfieldExtract(uint(light_color), 6, 5),
					light_color & uint16_t(63u),
					light_color >> uint16_t(11u)
				);

				immut float16_t light_diffuse = face_n_dot_l > float16_t(0.0) ? face_n_dot_l / float16_t(PI) : float16_t(IND_ILLUM + 0.04); // add IND_ILLUM for fake "GI", with additional (+0.04, just picked at random) term not found in the solid version, to also fake light spreading through the material

				diffuse = fma(light_diffuse.xxx, illum, diffuse);
			}
		}

		// Undo the multiplication from packing light color and brightness
		const vec3 packing_scale = 15.0 * vec3(31.0, 63.0, 31.0);
		immut f16vec3 new_light = f16vec3(float(INDEXED_BLOCK_LIGHT * 3) / packing_scale) * light.x * diffuse;

		block_light = mix(new_light, block_light, smoothstep(float16_t(INDEX_DIST - 15), float16_t(INDEX_DIST), chebyshev_dist));
	}

	#ifdef NETHER
		const f16vec3 sky_light = f16vec3(0.3, 0.15, 0.2);
	#elif defined END
		const f16vec3 sky_light = f16vec3(0.15, 0.075, 0.2);
	#else
		immut float16_t sky_light = float16_t(1.0) - sqrt(float16_t(1.0) - light.y);
	#endif

	return fma(f16vec3(sky_light), f16vec3(0.375), block_light);
}
