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
	#include "/lib/tbn/fsh.glsl"
#endif

in VertexData {
	layout(location = 2, component = 0) vec3 tint;
	layout(location = 3, component = 0) vec3 light;
	layout(location = 4, component = 0) vec2 coord;

	#ifndef NETHER
		layout(location = 5, component = 0) vec3 s_screen;
	#endif

	#if !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)
		layout(location = 0, component = 3) flat uint mid_coord;
		layout(location = 6, component = 0) flat uint face_tex_size;
	#endif
} v;

#ifndef NETHER
	uniform vec3 shadowLightDirection;

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

	immut f16vec3 tint = f16vec3(v.tint);

	#ifdef TERRAIN
		immut bool fluid = v_tbn.handedness_and_misc >= 0x80000000u; // most significant bit is set
		immut float16_t alpha = fluid ? float16_t(WATER_OPACITY * 0.01) : float16_t(1.0);
		color *= f16vec4(tint, alpha);
	#else
		color.rgb *= tint;
	#endif

	#if defined SM && defined MC_SPECULAR_MAP
		immut float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
	#else
		#ifdef TERRAIN
			immut float16_t avg_luma = unpackFloat2x16(v_tbn.handedness_and_misc >> 1u).x;
		#else
			const float16_t avg_luma = float16_t(0.8);
		#endif

		immut float16_t roughness = gen_roughness(luminance(color.rgb), avg_luma);
	#endif

	#if defined NO_NORMAL
		immut f16vec3 v_tex_normal = f16vec3(0.0, 0.0, 1.0);
	#else
		immut f16vec2 octa_v_face_normal = f16vec2(unpackFloat2x16(v_tbn.half2x16_octa_normal));
		immut f16vec2 octa_v_face_tangent = f16vec2(unpackFloat2x16(v_tbn.half2x16_octa_tangent));

		immut vec3 v_face_normal = vec3(normalize(octa_decode(octa_v_face_normal)));
		immut vec3 v_face_tangent = vec3(normalize(octa_decode(octa_v_face_tangent)));

		immut float handedness = fma(float(v_tbn.handedness_and_misc & 1u), 2.0, -1.0); // map least significant bit, [0u, 1u], to [-1.0, 1.0]

		immut mat3 v_tbn = mat3(v_face_tangent, cross(v_face_tangent, v_face_normal) * handedness, v_face_normal);

		#if NORMALS == 1 && defined MC_NORMAL_MAP
			immut f16vec3 v_tex_normal = f16vec3(v_tbn * sample_normal(texture(normals, v.coord).rg));
		#elif NORMALS == 2
			immut f16vec3 v_tex_normal = f16vec3(v_tbn[2]);
		#else
			immut f16vec3 v_tex_normal = f16vec3(v_tbn * gen_normal(gtexture, tint, v.coord, v.mid_coord, v.face_tex_size, luminance(color.rgb)));
		#endif
	#endif

	color.rgb = linear(color.rgb);

	immut vec3 ndc = fma(vec3(gl_FragCoord.xy / vec2(view_size()), gl_FragCoord.z), vec3(2.0), vec3(-1.0));
	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);

	f16vec3 lighting = f16vec3(v.light);

	#ifndef NETHER
		immut f16vec3 skylight = skylight();
		immut f16vec3 shadow_light_dir = f16vec3(shadowLightDirection);

		#ifdef NO_NORMAL
			const float16_t face_n_dot_l = float16_t(1.0);
			const float16_t tex_n_dot_l = float16_t(1.0);
		#else
			immut float16_t face_n_dot_l = dot(f16vec3(v_tbn[2]), shadow_light_dir);
			immut float16_t tex_n_dot_l = dot(v_tex_normal, shadow_light_dir);
		#endif

		#if SSS
			f16vec3 light = sample_shadow(v.s_screen);
		#endif

		if (min(face_n_dot_l, tex_n_dot_l) > min_n_dot_l) {
			#if !SSS
				f16vec3 light = sample_shadow(v.s_screen);
			#endif

			if (dot(light, f16vec3(1.0)) > float16_t(0.0)) {
				immut f16vec2 specular_diffuse = brdf(face_n_dot_l, v_tex_normal, f16vec3(normalize(view)), shadow_light_dir, roughness);

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
