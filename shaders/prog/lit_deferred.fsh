#include "/prelude/core.glsl"

/* RENDERTARGETS: 1,2 */
#ifdef NETHER
	layout(location = 1) out uvec3 colortex2;
#else
	layout(location = 1) out uvec4 colortex2;
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
#endif

#include "/lib/octa_normal.glsl"
#include "/lib/luminance.glsl"
#include "/lib/material/specular.glsl"
#include "/lib/material/ao.glsl"
#include "/lib/material/normal.glsl"
#include "/lib/srgb.glsl"

in
#include "/lib/v_data_lit.glsl"

void main() {
	#ifdef TEX_ALPHA
		f16vec4 color = f16vec4(texture(gtexture, v.coord));

		#ifdef ALPHA_CHECK
			immut bool will_discard = color.a < float16_t(alphaTestRef);

			if (subgroupAll(will_discard)) { discard; }
		#else
			const bool will_discard = false;
		#endif
	#else
		f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);
		const bool will_discard = false;
	#endif

	immut f16vec3 tint = f16vec3(
		#ifdef TERRAIN
			v.tint
		#else
			unpackUnorm4x8(v.unorm4x8_tint_zero).rgb
		#endif
	);
	color.rgb *= tint;

	immut float16_t srgb_luma = luminance(color.rgb);
	immut float16_t avg_srgb_luma = abs(unpackFloat2x16(v.misc_packed).y);

	#ifdef TERRAIN
		/*
			immut uint16_t packed_alpha = uint16_t(bitfieldExtract(v.misc_packed, 5, 11));

			if (packed_alpha != uint16_t(2047u)) {
				// TODO: Render sky and mix for fade effect.
				// Alternatively dither transparency.
			}
		*/
	#endif

	#ifdef NO_NORMAL
		immut f16vec3 w_face_normal = f16vec3(mvInv2); // == MV_INV * vec3(0.0, 0.0, 1.0)
		immut f16vec2 octa_w_face_normal = octa_encode(f16vec3(w_face_normal));
	#else
		immut f16vec4 octa_tangent_normal = f16vec4(unpackSnorm4x8(v.snorm4x8_octa_tangent_normal));
		immut f16vec2 octa_w_face_normal = octa_tangent_normal.zw;
		immut f16vec3 w_face_normal = normalize(octa_decode(octa_w_face_normal));
	#endif

	#if defined NO_NORMAL || NORMALS == 2
		immut f16vec3 w_tex_normal = w_face_normal;
		immut f16vec2 octa_w_tex_normal = octa_w_face_normal;
	#else
		immut f16vec3 w_face_tangent = normalize(octa_decode(octa_tangent_normal.xy));
		immut float16_t handedness = fma(float16_t(bitfieldExtract(v.misc_packed, 4, 1)), float16_t(-2.0), float16_t(1.0));

		// TODO: It looks like something is wrong here. Some normals seem inverted/flipped.
		immut mat3 w_tbn = mat3(w_face_tangent, vec3(cross(w_face_tangent, w_face_normal) * handedness), w_face_normal);

		#if NORMALS == 1 && defined MC_NORMAL_MAP
			immut f16vec3 w_tex_normal = f16vec3(w_tbn * sample_normal(texture(normals, v.coord).rg));
		#else
			immut f16vec3 w_tex_normal = f16vec3(w_tbn * gen_normal(gtexture, tint, v.coord, v.unorm2x16_mid_coord, v.uint2x16_face_tex_size, srgb_luma));

			/*
				immut ivec2 half_texels = ivec2(unpackUint2x16(
					v.uint2x16_face_tex_size
				) / uint16_t(2u) - uint16_t(1u));

				immut vec2 local_coord = v.coord - unpackUnorm2x16(v.unorm2x16_mid_coord);
				immut ivec2 local_texel = ivec2(local_coord * vec2(textureSize(gtexture, 0)));

				color.rgb += vec4(
					local_texel.x > -half_texels.x,
					local_texel.x < half_texels.x,
					local_texel.y > -half_texels.y,
					local_texel.y < half_texels.y
				).rgb;
			*/
		#endif

		immut f16vec2 octa_w_tex_normal = octa_encode(w_tex_normal);
	#endif

	#ifdef NETHER
		colortex2.b
	#else
		colortex2.a
	#endif
		= packSnorm4x8(f16vec4(octa_w_tex_normal, octa_w_face_normal));

	{
		uint data = (
			#ifdef TERRAIN
				packHalf2x16(vec2(v.light.y, 0.0))
			#else
				v.float2x16_light >> 16u
			#endif
		); // The sign bit (#15) is always zero.

		#ifdef TERRAIN
			float16_t ao = corner_ao_curve(float16_t(v.ao));
		#else
			float16_t ao = float16_t(1.0);
		#endif

		ao *= gen_tex_ao(srgb_luma, avg_srgb_luma); // TODO: LabPBR AO support.

		data = bitfieldInsert(
			data, uint(fma(ao, float16_t(8191.0), float16_t(0.5))),
			15, 13
		);

		// TODO: AO direction.

		#ifdef HAND
			data |= 0x80000000u; // Set most significant bit to 1.
		#endif

		#ifdef NETHER
			colortex2.g
		#else
			colortex2.b
		#endif
			= data;
	}

	{
		immut bool is_metal = uint8_t(v.misc_packed >> 31u) == uint8_t(1u); // TODO: LabPBR.
		// const float16_t f0 = float16_t(0.04); // TODO: Uncomment and use when f0 isn't constant.
		immut float16_t f0_enum = is_metal ? float16_t(231.0 / 255.0) : 0.0;

		const float16_t sss = float16_t(0.0); // TODO: LabPBR SSS map support.

		#if defined SM && defined MC_SPECULAR_MAP
			float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
		#else
			float16_t roughness = gen_roughness(srgb_luma, avg_srgb_luma, is_metal ? float16_t(-0.1) : float16_t(0.1));
		#endif

		uint data = packUnorm4x8(f16vec4(roughness, sss, 0.0, f0_enum));

		#if defined TERRAIN || defined HAND
			uint8_t emission = uint8_t(v.misc_packed) & uint8_t(15u);
			emission *= uint8_t(17u); // Scale to full `uint8_t` range.

			// TODO: LabPBR emission map support.

			data = bitfieldInsert(data, uint(emission), 16, 8);
		#endif

		#ifdef NETHER
			colortex2.r
		#else
			colortex2.g
		#endif
			= data;
	}

	if (will_discard) {
		discard;
	} else if (gl_HelperInvocation) {
		return;
	} else {
		#ifndef NETHER
			colortex2.r = floatBitsToUint(v.s_distortion);
		#endif

		immut float16_t block_light = (
			#ifdef TERRAIN
				float16_t(v.light.x)
			#else
				unpackFloat2x16(v.float2x16_light).x
			#endif
		);

		colortex1 = f16vec4(linear(color.rgb), block_light);
	}
}
