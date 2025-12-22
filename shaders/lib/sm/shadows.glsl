#include "/lib/sm/sample.glsl"
#include "/lib/brdf.glsl"
#include "/lib/sm/bias.glsl"

#if SM_BLUR == 2
	// Terrible generated versions of 'sample_sm' from '/lib/sm/sample.glsl' with offsets.
	// `const` parameters don't work here (probably since they're patched away by Iris)
	// and using a non-const parameter causes compile failures on AMD :(

	#define SAMPLE_SM(X, Y) \
		const ivec2 offset = ivec2(X, Y); \
		immut float16_t solid_vis = float16_t(textureLodOffset(shadowtex1HW, s_scrn, 0.0, offset).r); \
		if (solid_vis == float16_t(0.0)) { \
			return f16vec3(0.0); \
		} else { \
			immut float16_t trans_vis = float16_t(textureLodOffset(shadowtex0HW, s_scrn, 0.0, offset).r); \
			f16vec3 color = (mul * solid_vis).xxx; \
			if (trans_vis < solid_vis) { color = mix(color * f16vec3(textureLodOffset(shadowcolor0, s_scrn.xy, 0.0, offset).rgb), color, trans_vis); } \
			return color; \
		} \

	#define SAMPLE_SM_ARGS float16_t mul, vec3 s_scrn

	f16vec3 sample_sm_0_n2(SAMPLE_SM_ARGS) { SAMPLE_SM(0, -2) }
	f16vec3 sample_sm_0_2(SAMPLE_SM_ARGS) { SAMPLE_SM(0, 2) }

	f16vec3 sample_sm_n2_n2(SAMPLE_SM_ARGS) { SAMPLE_SM(-2, -2) }
	f16vec3 sample_sm_n2_0(SAMPLE_SM_ARGS) { SAMPLE_SM(-2, 0) }
	f16vec3 sample_sm_n2_2(SAMPLE_SM_ARGS) { SAMPLE_SM(-2, 2) }

	f16vec3 sample_sm_2_n2(SAMPLE_SM_ARGS) { SAMPLE_SM(2, -2) }
	f16vec3 sample_sm_2_0(SAMPLE_SM_ARGS) { SAMPLE_SM(2, 0) }
	f16vec3 sample_sm_2_2(SAMPLE_SM_ARGS) { SAMPLE_SM(2, 2) }
#endif

f16vec3 sample_shadow(vec3 s_scrn) {
	#if SM_BLUR < 2
		#if !SM_BLUR
			/*
				const bool shadowtex0Nearest = true;
				const bool shadowtex1Nearest = true;
				const bool shadowcolor0Nearest = true;
			*/
		#endif

		return sample_sm(float16_t(1.0), s_scrn);
	#else
		// Gaussian blur approximation based on: https://web.archive.org/web/20230210095515/http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/

		const float sm_res = float(shadowMapResolution);

		vec2 base_uv;
		immut f16vec2 st = f16vec2(modf(fma(s_scrn.xy, sm_res.xx, vec2(0.5)), base_uv));
		base_uv = fma(base_uv, vec2(1.0 / sm_res), vec2(-0.5 / sm_res));

		immut f16vec2 uvw0 = fma(st, f16vec2(-3.0), f16vec2(4.0));
		const vec2 uvw1_f32 = vec2(7.0); // Might as well do const 32-bit if we can.
		const f16vec2 uvw1 = f16vec2(uvw1_f32);
		immut f16vec2 uvw2 = fma(st, f16vec2(3.0), f16vec2(1.0));

		immut vec2 uv0 = vec2(fma(st, f16vec2(-2.0 / sm_res), f16vec2(3.0 / sm_res)) / uvw0);
		immut vec2 uv1 = vec2(fma(st, f16vec2(1.0 / (sm_res * uvw1_f32)), f16vec2(3.0 / (sm_res * uvw1_f32))));
		immut vec2 uv2 = vec2(st / (float16_t(sm_res) * uvw2));

		return (
			uvw0.y * (
				sample_sm_n2_n2(uvw0.x, vec3(base_uv + vec2(uv0.x, uv0.y), s_scrn.z)) +
				sample_sm_0_n2(uvw1.x, vec3(base_uv + vec2(uv1.x, uv0.y), s_scrn.z)) +
				sample_sm_2_n2(uvw2.x, vec3(base_uv + vec2(uv2.x, uv0.y), s_scrn.z))
			) + uvw1.y * (
				sample_sm_n2_0(uvw0.x, vec3(base_uv + vec2(uv0.x, uv1.y), s_scrn.z)) +
				sample_sm(uvw1.x, vec3(base_uv + vec2(uv1.x, uv1.y), s_scrn.z)) +
				sample_sm_2_0(uvw2.x, vec3(base_uv + vec2(uv2.x, uv1.y), s_scrn.z))
			) + uvw2.y * (
				sample_sm_n2_2(uvw0.x, vec3(base_uv + vec2(uv0.x, uv2.y), s_scrn.z)) +
				sample_sm_0_2(uvw1.x, vec3(base_uv + vec2(uv1.x, uv2.y), s_scrn.z)) +
				sample_sm_2_2(uvw2.x, vec3(base_uv + vec2(uv2.x, uv2.y), s_scrn.z))
			)
		) / float16_t(144.0);
	#endif
}
