#include "/prelude/core.glsl"

/* RENDERTARGETS: 1 */
layout(location = 0) out f16vec4 colortex1;

#ifdef ALPHA_CHECK
	layout(depth_greater) out float gl_FragDepth;

	uniform float alphaTestRef;
#else
	layout(depth_unchanged) out float gl_FragDepth;
#endif

#include "/lib/mv_inv.glsl"
uniform mat4 gbufferProjectionInverse;
uniform sampler2D gtexture;

#ifdef NO_NORMAL
	uniform mat3 normalMatrix;
#else
	#include "/lib/octa_normal.glsl"
#endif

#define TRANSLUCENT
in
#include "/lib/lit_v_data.glsl"

#ifndef NETHER
	uniform vec3 shadowLightDirectionPlr;

	#include "/lib/skylight.glsl"
	#include "/lib/sm/distort.glsl"
	#include "/lib/sm/shadows.glsl"
#endif

#ifdef END
	uniform float frameTimeCounter;
	#include "/lib/prng/fast_rand.glsl"
#endif

#include "/lib/view_size.glsl"
#include "/lib/mmul.glsl"
#include "/lib/luminance.glsl"
#include "/lib/srgb.glsl"
#define SKY_FSH
#include "/lib/fog.glsl"
#include "/lib/material/specular.glsl"

#ifndef NO_NORMAL
	#include "/lib/material/normal.glsl"
#endif

void main() {
	f16vec4 color = f16vec4(texture(gtexture, v.coord));

	#ifdef ALPHA_CHECK
		if (color.a < float16_t(alphaTestRef)) discard;
	#endif

	immut f16vec3 tint = f16vec3(
		#ifdef TERRAIN
			v.tint
		#else
			unpackUnorm4x8(v.unorm4x8_tint_zero).rgb
		#endif
	);
	color.rgb *= tint;

	immut uint16_t packed_alpha = uint16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 5, 11));
	color.a *= float16_t(1.0/2047.0) * float16_t(packed_alpha);

	#if defined SM && defined MC_SPECULAR_MAP
		immut float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
	#else
		immut float16_t avg_luma = unpackFloat2x16(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma).y;

		immut float16_t roughness = gen_roughness(luminance(color.rgb), avg_luma);
	#endif

	#ifdef NO_NORMAL
		immut f16vec3 w_face_normal = f16vec3(mvInv2);
		immut f16vec3 w_tex_normal = w_face_normal;
	#else
		immut f16vec4 octa_tangent_normal = unpackSnorm4x8(v.snorm4x8_octa_tangent_normal);

		immut f16vec3 w_face_tangent = normalize(octa_decode(octa_tangent_normal.xy));
		immut f16vec3 w_face_normal = normalize(octa_decode(octa_tangent_normal.zw));

		#if NORMALS == 2
			immut f16vec3 w_tex_normal = w_face_normal;
		#else
			immut float16_t handedness = fma(float16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 4, 1)), float16_t(2.0), float16_t(-1.0));

			immut mat3 w_tbn = mat3(w_face_tangent, vec3(cross(w_face_tangent, w_face_normal) * handedness), w_face_normal);

			#if NORMALS == 1 && defined MC_NORMAL_MAP
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * sample_normal(texture(normals, v.coord).rg));
			#else
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * gen_normal(gtexture, tint, v.coord, v.unorm2x16_mid_coord, v.uint2x16_face_tex_size, luminance(color.rgb)));
			#endif
		#endif
	#endif

	color.rgb = linear(color.rgb);

	immut vec3 ndc = fma(vec3(gl_FragCoord.xy / vec2(view_size()), gl_FragCoord.z), vec3(2.0), vec3(-1.0));
	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);

	f16vec3 lighting = f16vec3(v.light);

	#ifndef NETHER
		immut f16vec3 skylight = skylight();
		immut f16vec3 n_w_shadow_light = f16vec3(shadowLightDirectionPlr);

		#ifdef NO_NORMAL
			const float16_t face_n_dot_l = float16_t(1.0);
			const float16_t tex_n_dot_l = float16_t(1.0);
		#else
			immut float16_t face_n_dot_l = dot(w_face_normal, n_w_shadow_light);
			immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_shadow_light);
		#endif

		#if SSS
			f16vec3 light = sample_shadow(v.s_screen);
		#endif

		if (min(face_n_dot_l, tex_n_dot_l) > float16_t(0.0)) {
			#if !SSS
				f16vec3 light = sample_shadow(v.s_screen);
			#endif

			if (dot(light, f16vec3(1.0)) > float16_t(0.0)) {
				immut f16vec2 specular_diffuse = brdf(face_n_dot_l, w_tex_normal, f16vec3(normalize(view)), n_w_shadow_light, roughness);

				light *= float16_t(3.0) * (specular_diffuse.y + specular_diffuse.x / max(color.rgb, float16_t(1.0e-5)));

				lighting = fma(light, skylight, lighting);
			}
		}

		#if SSS
			else lighting = fma(light, skylight, lighting);  // TODO: We should use AO here.
		#endif
	#endif

	color.rgb *= lighting;

	/*
		immut float solid_depth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;

		if (solid_depth < 1.0) {
			immut vec3 solid_ndc = fma(vec3(gl_FragCoord.xy / vec2(view_size()), solid_depth), vec3(2.0), vec3(-1.0));
			immut vec3 solid_pe = mat3(gbufferModelViewInverse) * proj_inv(gbufferProjectionInverse, solid_ndc);
			immut float16_t fog = min(fog(solid_pe) + float16_t(1.0 - exp(-0.0125 / fogState.y * length(solid_pe))), float16_t(1.0)); // TODO: Make this less cursed.

			#if defined END || defined NETHER
				color.rgb = mix(color.rgb, color.rgb * linear(f16vec3(fogColor)), fog);
			#else
				immut vec3 n_pe = normalize(solid_pe);
				immut float16_t sky_fog = sky_fog(float16_t(n_pe.y));
				immut f16vec3 fog_col = sky(sky_fog, n_pe, mat3(gbufferModelViewInverse) * shadowLightDirection);
				color.rgb = mix(color.rgb, mix(color.rgb * fog_col, fog_col, fog), fog);
			#endif

			color.a = saturate(color.a + fog);
		} // TODO: Self-colored fog should be based on the distance between the current surface and the solid one behind it, not the distance from the camera to the solid surface.
	*/

	color.a *= float16_t(1.0) - vanilla_fog(MV_INV * view + mvInv3);

	colortex1 = color;
}
