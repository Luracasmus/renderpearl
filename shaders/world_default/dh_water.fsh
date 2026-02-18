#include "/prelude/core_compatibility.glsl"

/* RENDERTARGETS: 1 */
layout(location = 0) out f16vec4 colortex1;
layout(depth_greater) out float gl_FragDepth;

uniform sampler2D depthtex0;
uniform mat4 dhProjectionInverse;
uniform int dhRenderDistance;

#include "/lib/mmul.glsl"
#include "/lib/mv_inv.glsl"
#include "/lib/octa_normal.glsl"

#ifdef LIGHT_LEVELS
	#include "/lib/llv.glsl"
#endif

in
#include "/lib/v_data_dh.glsl"

#ifndef NETHER
	uniform float frameTimeCounter;
	uniform vec3 shadowLightDirectionPlr;
	uniform mat4 shadowModelView;

	#include "/lib/prng/pcg.glsl"

	#ifdef END
		#include "/lib/prng/fast_rand.glsl"
		uniform float endFlashIntensity;
	#else
		uniform vec3 sunDirectionPlr;
	#endif

	#include "/lib/brdf.glsl"
	#include "/lib/skylight.glsl"
	#include "/lib/sm/distort.glsl"
	#include "/lib/light/shadows.glsl"
#endif

#include "/lib/view_size.glsl"
#include "/lib/srgb.glsl"
#include "/lib/luminance.glsl"
#define SKY_FSH
#include "/lib/fog.glsl"
#include "/lib/material/ao.glsl"
#include "/lib/light/non_block.glsl"

void main() {
	if (!gl_HelperInvocation) {
		if (texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r < 1.0) {
			discard;
		} else {
			f16vec4 color = f16vec4(unpackUnorm4x8(v.unorm4x8_color));

			vec3 ndc = fma(vec3(gl_FragCoord.xy / vec2(view_size()), gl_FragCoord.z), vec3(2.0), vec3(-1.0));
			immut vec3 view = proj_inv(dhProjectionInverse, ndc);

			f16vec3 light = f16vec3(
				(v.snorm2x8_bool1_zero15_normal_emission > 65536u) ? float16_t(EMISSION_BRIGHTNESS) : float16_t(0.0)
			);
			immut f16vec2 block_sky_light = unpackFloat2x16(v.float2x16_light);

			immut f16vec3 w_normal = octa_decode(f16vec2(unpackSnorm4x8(v.snorm2x8_bool1_zero15_normal_emission).xy));

			#if DIR_SHADING != 0
				immut float16_t ao = dir_shading(w_normal);
			#else
				const float16_t ao = float16_t(1.0);
			#endif

			#ifdef LIGHT_LEVELS
				immut f16vec3 block_light = f16vec3(visualize_ll(block_sky_light.x));
			#else
				immut f16vec3 block_light = block_sky_light.x * f16vec3(BL_FALLBACK_R, BL_FALLBACK_G, BL_FALLBACK_B);
			#endif

			light += block_light;

			#ifdef NETHER
				const f16vec3 sky_light_color = f16vec3(0.0);
			#else
				immut f16vec3 sky_light_color = skylight();
			#endif

			light += ao * non_block_light(sky_light_color, block_sky_light.y);

			immut vec3 pe = MV_INV * view;

			#ifndef NETHER
				immut f16vec3 n_pe = f16vec3(normalize(pe));
				immut f16vec3 abs_pe = abs(f16vec3(pe));
				immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

				immut f16vec3 rcp_color = float16_t(1.0) / max(color.rgb, float16_t(1.0e-5));

				immut f16vec3 n_w_shadow_light = f16vec3(shadowLightDirectionPlr);

				#ifdef NO_NORMAL
					const float16_t n_dot_l = float16_t(1.0);
				#else
					immut float16_t n_dot_l = dot(w_normal, n_w_shadow_light);
				#endif

				const float16_t roughness = float16_t(0.8);

				sample_shadow(
					light,
					chebyshev_dist, v.s_distortion,
					sky_light_color, rcp_color, roughness,
					n_dot_l, n_dot_l, n_w_shadow_light,
					w_normal, w_normal, n_pe, pe
				);
			#endif

			immut f16vec3 pf = f16vec3(pe + mvInv3);

			colortex1 = color * f16vec4(
				light,
				// Fade in where regular translucents fade out, and then fade out again at DH render distance. TODO: It might be possible to make the transition smoother.
				// TODO: Skip shading and stuff far inside the regular RD.
				1.0 - vanilla_fog(pf, float16_t(dhRenderDistance))
			);
		}
	}
}
