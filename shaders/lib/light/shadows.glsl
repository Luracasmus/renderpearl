#include "/lib/sm/sample.glsl"

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

f16vec3 smooth_sample_sm(vec3 s_scrn) {
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

// Sample the shadow map with bias,
// applying BRDF-based lighting and a fade at the edges of the shadow distance.
void sample_shadow(
	inout f16vec3 light,
	float16_t chebyshev_dist, float s_distortion,
	f16vec3 sky_light_color, f16vec3 rcp_color, float16_t roughness,
	float16_t face_n_dot_l, float16_t tex_n_dot_l, f16vec3 n_w_shadow_light,
	f16vec3 w_tex_normal, f16vec3 n_pe, vec3 pe
) {
	if (min(face_n_dot_l, tex_n_dot_l) > min_n_dot_l) {
		const float16_t sm_dist = float16_t(shadowDistance * shadowDistanceRenderMul);
		immut f16vec2 specular_diffuse = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_shadow_light, roughness);

		f16vec3 dir_sky_light = sky_light_color * fma(specular_diffuse.xxx, rcp_color, specular_diffuse.yyy);

		if (chebyshev_dist < sm_dist) {
			vec3 s_view = rot_trans_mmul(shadowModelView, pe + mvInv3);

			immut float16_t sine = sqrt(fma(face_n_dot_l, -face_n_dot_l, float16_t(1.0))); // Using the Pythagorean identity.
			immut float16_t tangent = sine / face_n_dot_l;
			immut float bias = tangent / (shadowMapResolution * shadow_proj_scale.x) / s_distortion * 9;

			s_view.z += bias.x;

			vec3 s_ndc = shadow_proj_scale.xxy * s_view;
			s_ndc.xy *= s_distortion;

			vec3 s_screen = fma(s_ndc, vec3(0.5), vec3(0.5));

			dir_sky_light *= mix(
				smooth_sample_sm(s_screen),
				f16vec3(1.0),
				smoothstep(float16_t(sm_dist * (1.0 - SM_FADE_DIST)), sm_dist, chebyshev_dist)
			);
		}

		light += float16_t(3.0) * dir_sky_light;
	}
}
