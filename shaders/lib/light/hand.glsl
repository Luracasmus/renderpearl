uniform int handLightPackedLR;
#include "/lib/un11_11_10.glsl"

#if HAND_LIGHT_TRACE_STEPS != 0
	uniform mat4 gbufferProjection;
	uniform sampler2D depthtex2;
#endif

f16vec3 get_hand_light(
	uint16_t light_level, uint packed_hl,
	vec3 origin_view, vec3 view, vec3 pe, f16vec3 n_pe,
	float16_t roughness, float16_t f0, bool is_metal,
	f16vec3 w_tex_normal, f16vec3 w_face_normal,
	f16vec3 color, f16vec3 rcp_color,
	float16_t ind_bl, bool is_hand
) {
	immut f16vec3 pe_to_light = f16vec3(MV_INV * origin_view - pe);
	immut float16_t sq_dist = dot(pe_to_light, pe_to_light);
	immut f16vec3 n_w_rel_light = pe_to_light * inversesqrt(sq_dist);

	immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_rel_light);

	immut float16_t brightness = float16_t(light_level) * float16_t(HAND_LIGHT) / max(sq_dist, float16_t(0.17));
	immut f16vec3 illum = brightness * unpack_un11_11_10(packed_hl);

	f16vec3 light;

	if (min(tex_n_dot_l, dot(w_face_normal, n_w_rel_light)) > min_n_dot_l) {
		f16vec3 reflected = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, roughness, f0, is_metal, color, rcp_color);

		#if HAND_LIGHT_TRACE_STEPS != 0
			const float trace_dist = float(MAX_HAND_LIGHT_TRACE_DIST);
			if (sq_dist < float16_t(trace_dist*trace_dist) && !is_hand) { // Ray trace if not hand and within tracing range.
				immut vec3 abs_pe = abs(pe);
				// immut uint steps = clamp(uint(log2(max3(abs_pe.x, abs_pe.y, abs_pe.z)) * HAND_LIGHT_TRACE_STEPS), 8u, HAND_LIGHT_TRACE_STEPS * 4);
				const uint steps = uint(HAND_LIGHT_TRACE_STEPS);

				f16vec4 from = f16vec4(proj_mmul(gbufferProjection, origin_view));
				f16vec4 to = f16vec4(proj_mmul(gbufferProjection, view));

				// Do multiplication part of ndc -> screen out here.
				from.xyz *= float16_t(0.5);
				to.xyz *= float16_t(0.5);

				immut f16vec4 step = (to - from) / float16_t(steps + 1);
				f16vec4 ray_halfclip = from;

				#if HAND_LIGHT_TRACE_HARDNESS != 0
					float16_t visibility = float16_t(steps);
				#else
					bool occluded = false;
				#endif

				for (uint i = 0u; i < steps; ++i) {
					ray_halfclip += step;

					immut f16vec2 ray_screen_undiv_xy = fma(ray_halfclip.ww, f16vec2(0.5), ray_halfclip.xy);
					// immut ivec2 texel = ivec2(ray_screen.xy * view_size());

					// immut vec4 depth_samples = textureGather(depthtex2, trace_screen.xy, 0);
					// immut bvec4 visible_samples = greaterThan(trace_screen.zzzz, depth_samples); // step just doesn't work here on AMD Mesa for some reason

					immut float16_t sampled = float16_t(textureProjLod(depthtex2, f16vec3(ray_screen_undiv_xy, ray_halfclip.w), 0.0).r);

					#if HAND_LIGHT_TRACE_HARDNESS != 0
						// TODO: Maybe reduce visibility less when the sample is further behind the blocker (as to not assume every blocker is infinitely deep).
						visibility -= float16_t((sampled - float16_t(0.5)) * ray_halfclip.w < ray_halfclip.z);
						// ^Equivalent to, but faster than, converting the ray position to screen space:
						// visibility -= float16_t(sampled < ray_halfclip.z / ray_halfclip.w + float16_t(0.5));
					#else
						if ((sampled - float16_t(0.5)) * ray_halfclip.w < ray_halfclip.z) {
							occluded = true;
						}
					#endif
				}

				#if HAND_LIGHT_TRACE_HARDNESS != 0
					/*
						if (visibility <= float16_t(steps) * float16_t(0.5)) { // Adjust this to make shadows soft or hard
							return ind_bl * illum;
						}
					*/

					reflected *= pow(visibility / float16_t(steps), float16_t(float(steps * uint(HAND_LIGHT_TRACE_HARDNESS)) / 8.0));
				#else
					if (occluded) {
						reflected = f16vec3(0.0);
					}
				#endif
			}
		#endif

		light = reflected + ind_bl;
	} else {
		light = ind_bl.xxx;
	}

	return light * illum;
}
