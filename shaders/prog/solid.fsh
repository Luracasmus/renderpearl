#include "/prelude/core.glsl"

#ifdef NETHER
	/* RENDERTARGETS: 1,2 */
	layout(location = 1, component = 1) out uvec3 colortex2;
#else
	/* RENDERTARGETS: 1,2,3 */
	layout(location = 1) out uvec4 colortex2;
	layout(location = 2) out u16vec2 colortex3;
#endif

layout(location = 0) out f16vec4 colortex1;

#ifdef ALPHA_CHECK
	layout(depth_greater) out float gl_FragDepth;
	uniform float alphaTestRef;
#else
	layout(depth_unchanged) out float gl_FragDepth;
#endif

uniform sampler2D gtexture;

#ifdef NO_NORMAL
	#include "/lib/mv_inv.glsl"
	#include "/lib/octa_normal.glsl"
#endif

#include "/lib/ao_curve.glsl"
#include "/lib/luminance.glsl"
#include "/lib/material/specular.glsl"
#include "/lib/material/normal.glsl"
#include "/lib/srgb.glsl"

in VertexData {
	layout(location = 0, component = 0) vec2 coord;
	layout(location = 1, component = 0) flat uint uint4_bool1_unorm11_float16_emission_handedness_alpha_luma;

	#ifdef TERRAIN
		layout(location = 0, component = 2) vec2 light;
		layout(location = 1, component = 1) flat uint snorm4x8_octa_tangent_normal;
		layout(location = 1, component = 2) flat uint unorm2x16_mid_coord;
		layout(location = 1, component = 3) flat uint uint2x16_face_tex_size;
		layout(location = 2, component = 0) vec3 tint;
		layout(location = 2, component = 3) float ao;

		#ifndef NETHER
			layout(location = 3, component = 0) vec3 s_screen;
		#endif
	#else
		layout(location = 1, component = 1) flat uint unorm4x8_tint_zero;
		layout(location = 1, component = 2) flat uint float2x16_light;

		#ifndef NETHER
			layout(location = 2, component = 0) vec3 s_screen;
		#endif

		#ifndef NO_NORMAL
			layout(location = 1, component = 3) flat uint snorm4x8_octa_tangent_normal;

			#if NORMALS != 2 && !(NORMALS == 1 && defined MC_NORMAL_MAP)
				layout(location = 3, component = 0) flat uint unorm2x16_mid_coord;
				layout(location = 3, component = 1) flat uint uint2x16_face_tex_size;
			#endif
		#endif
	#endif
} v;

void main() {
	#ifdef TEX_ALPHA
		f16vec4 color = f16vec4(texture(gtexture, v.coord));

		#ifdef ALPHA_CHECK
			if (color.a < float16_t(alphaTestRef)) { discard; }
		#endif
	#else
		f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);
	#endif

	immut f16vec3 tint = f16vec3(
		#ifdef TERRAIN
			v.tint
		#else
			unpackUnorm4x8(v.unorm4x8_tint_zero).rgb
		#endif
	);

	#ifdef TERRAIN
		immut uint16_t packed_alpha = uint16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 5, 11));

		if (packed_alpha != uint16_t(2047u)) {
			// TODO: Render sky and mix for fade effect.
			// Alternatively dither transparency.
		}
	#endif

	color.rgb *= tint;

	// #if (NORMALS != 2 && !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)) || !(defined SM && defined MC_SPECULAR_MAP)
		immut float16_t luma = luminance(color.rgb);
	// #endif

	immut float16_t avg_luma = unpackFloat2x16(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma).y;

	{
		#ifdef NO_NORMAL
			immut vec3 w_face_normal = mvInv2; // == MV_INV * vec3(0.0, 0.0, 1.0)
			immut f16vec2 octa_w_face_normal = octa_encode(f16vec3(w_face_normal));
		#else
			immut f16vec4 octa_tangent_normal = unpackSnorm4x8(v.snorm4x8_octa_tangent_normal);
			immut f16vec2 octa_w_face_normal = octa_tangent_normal.zw;
			immut f16vec3 w_face_normal = octa_decode(octa_w_face_normal);
		#endif

		#if defined NO_NORMAL || NORMALS == 2
			immut f16vec2 octa_w_tex_normal = octa_w_face_normal;
		#else
			#ifdef NO_NORMAL
				immut vec3 w_face_tangent = mvInv1; // == MV_INV * vec3(0.0, 1.0, 0.0)
				immut mat3 w_tbn = mat3(w_face_tangent, cross(w_face_tangent, w_face_normal), w_face_normal);
			#else
				immut f16vec2 octa_w_face_tangent = octa_decode(octa_tangent_normal);
				immut vec3 w_face_tangent = vec3(normalize(octa_decode(octa_w_face_tangent)));
				immut vec3 w_face_normal = vec3(normalize(octa_decode(octa_w_face_normal)));

				immut float16_t handedness = fma(float16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 4, 1)), float16_t(2.0), float16_t(-1.0));

				immut mat3 w_tbn = mat3(w_face_tangent, cross(w_face_tangent, w_face_normal) * handedness, w_face_normal);
			#endif

			#if NORMALS == 1 && defined MC_NORMAL_MAP
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * sample_normal(texture(normals, v.coord).rg));
			#else
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * gen_normal(gtexture, tint, v.coord, v.mid_coord, v.face_tex_size, luma));

				/*
					immut ivec2 half_texels = ivec2(
						v.face_tex_size & 65535u,
						v.face_tex_size >> 16u
					) / 2 - 1;
					immut vec2 atlas = vec2(textureSize(gtexture, 0));
					immut vec2 atlas_texel = 1.0 / atlas;
					immut vec2 half_size = vec2(half_texels) * atlas_texel;

					immut vec2 local_coord = v.coord - unpackUnorm2x16(v.mid_coord);
					color.rgb += vec4(
						local_coord.x > -half_size.x,
						local_coord.x < half_size.x,
						local_coord.y > -half_size.y,
						local_coord.y < half_size.y
					).rgb;
				*/
			#endif

			immut f16vec2 octa_w_tex_normal = octa_encode(w_tex_normal);
		#endif

		colortex2.a = packSnorm4x8(f16vec4(octa_w_tex_normal, octa_w_face_normal));
	}

	color.rgb = linear(color.rgb);

	{
		immut uint data = (
			#ifdef TERRAIN
				packHalf2x16(vec2(v.light.y, 0.0));
			#else
				v.float2x16_light >> 16u
			#endif
		); // The sign bit (#15) is always zero.

		#ifdef TERRAIN
			immut float16_t in_ao = float16_t(v.ao);

			float16_t ao = ao_curve(in_ao);
		#else
			float16_t ao = float16_t(0.9);
		#endif

		ao = saturate(fma(luma - avg_luma, float16_t(0.5), ao)); // TODO: Make the multiplier here a configurable value.

		// TODO: labPBR AO map support.

		data = bitfieldInsert(
			data, fma(ao, float16_t(8192.0), float16_t(0.5)),
			15, 13
		);

		// TODO: AO direction.

		#ifdef HAND
			data |= 0x80000000u; // Set most significant bit to 1.
		#endif

		colortex2.b = data;
	}

	{
		#if defined SM && defined MC_SPECULAR_MAP
			float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
		#else
			float16_t roughness = gen_roughness(luma, avg_luma);
		#endif

		const float16_t sss = float16_t(0.0); // TODO: labPBR SSS map support.

		uint data = packUnorm4x8(f16vec4(roughness, sss, 0.0, 0.0));

		#if defined TERRAIN || defined HAND
			immut uint8_t emission = uint8_t(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma) & uint8_t(15u);
			color *= fma(float16_t(emission), float16_t(2.0/15.0), float16_t(1.0)); // TODO: We should just add to the lighting in deferred instead of multiplying the color.

			emission *= uint8_t(17u); // Scale to full uint8_t range.

			// TODO: labPBR emission map support.

			data = bitfieldInsert(data, uint(emission), 16, 8);
		#endif

		// TODO: f0 enum.

		colortex2.g = data;
	}

	#ifndef NETHER
		{
			immut uvec3 packed_s_screen = uvec3(
				fma(v.s_screen, vec3(vec2(1048576.0), 16777216.0), vec3(0.5))
			); // Scale to (20, 20, 24)-bit uint range and round.

			colortex2.r = bitfieldInsert(
				bitfieldInsert(packed_s_screen.x, packed_s_screen.y, 4, 4),
				packed_s_screen.z,
				8, 24
			);

			colortex3 = u16vec2(packed_s_screen.xy >> 4u);
		}
	#endif

	colortex1 = f16vec4(color.rgb, float16_t(ao));
}
