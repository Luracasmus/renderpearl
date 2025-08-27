#include "/prelude/core.glsl"

/* RENDERTARGETS: 1,2 */
layout(location = 0) out f16vec4 colortex1; // does this work outside of NVIDIA drivers? (the f16*)

#ifdef NETHER
	layout(location = 1) out uvec3 colortex2;
#else
	layout(location = 1) out uvec4 colortex2;
#endif

#ifdef ALPHA_CHECK
	layout(depth_greater) out float gl_FragDepth;

	uniform float alphaTestRef;
#else
	layout(depth_unchanged) out float gl_FragDepth;
#endif

uniform sampler2D gtexture;

#ifdef NO_NORMAL
	uniform mat4 gbufferModelViewInverse;

	#include "/lib/octa_normal.glsl"
#else
	#include "/lib/tbn/fsh.glsl"
#endif

#include "/lib/luminance.glsl"
#include "/lib/material/specular.glsl"
#include "/lib/material/normal.glsl"
#include "/lib/srgb.glsl"

in VertexData {
	layout(location = 1, component = 0) vec2 coord;

	#ifdef HAND
		layout(location = 5, component = 0) flat vec2 light;
		layout(location = 2, component = 0) flat vec3 tint;
	#else
		layout(location = 1, component = 2) vec2 light;
		layout(location = 2, component = 0) vec3 tint;

		#ifdef TERRAIN
			layout(location = 2, component = 3) float ao;
		#endif
	#endif

	#ifndef NETHER
		layout(location = 3, component = 0) vec3 s_screen;
	#endif

	#if NORMALS != 2 && !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)
		layout(location = 0, component = 3) flat uint mid_coord;
		layout(location = 4, component = 0) flat uint face_tex_size;
	#endif
} v;

void main() {
	#ifdef TEX_ALPHA
		f16vec4 color = f16vec4(texture(gtexture, v.coord));

		#ifdef ALPHA_CHECK
			if (color.a < float16_t(alphaTestRef)) discard;
		#endif
	#else
		f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);
	#endif

	immut f16vec3 tint = f16vec3(v.tint);
	color.rgb *= tint;

	// #if (NORMALS != 2 && !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)) || !(defined SM && defined MC_SPECULAR_MAP)
		immut float16_t luma = luminance(color.rgb);
	// #endif

	#ifdef NO_NORMAL
		immut vec3 w_face_normal = mat3(gbufferModelViewInverse) * vec3(0.0, 0.0, 1.0);
		immut f16vec2 octa_w_face_normal = octa_encode(f16vec3(mat3(gbufferModelViewInverse) * vec3(0.0, 0.0, 1.0)));
	#else
		immut f16vec2 octa_w_face_normal = unpackFloat2x16(v_tbn.half2x16_octa_normal);
	#endif

	#if defined NO_NORMAL || NORMALS == 2
		immut f16vec2 octa_w_tex_normal = octa_w_face_normal;
	#else
		#ifdef NO_NORMAL
			immut vec3 w_face_tangent = mat3(gbufferModelViewInverse) * vec3(0.0, 1.0, 0.0);
			immut mat3 w_tbn = mat3(w_face_tangent, cross(w_face_tangent, w_face_normal), w_face_normal);
		#else
			immut f16vec2 octa_w_face_tangent = unpackFloat2x16(v_tbn.half2x16_octa_tangent);
			immut vec3 w_face_tangent = vec3(normalize(octa_decode(octa_w_face_tangent)));
			immut vec3 w_face_normal = vec3(normalize(octa_decode(octa_w_face_normal)));

			immut float handedness = fma(float(v_tbn.handedness_and_misc & 1u), 2.0, -1.0); // map least significant bit, [0u, 1u], to [-1.0, 1.0]

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

	color.rgb = linear(color.rgb);

	colortex2.r = packSnorm4x8(f16vec4(octa_w_tex_normal, octa_w_face_normal));

	{
		// we have to min() after conversion here because of float16_t precision at these high values
		immut uvec2 scaled_light = min(uvec2(fma(f16vec2(v.light), f16vec2(32767.0), f16vec2(0.5))), 32767u);
		uint data = bitfieldInsert(scaled_light.x, scaled_light.y, 15, 15);

		#if defined TERRAIN || defined HAND
			immut uint emission = bitfieldExtract(v_tbn.handedness_and_misc, 1, 4); // TODO: should be 8 bits // TODO: labPBR emission map support
			color *= fma(float16_t(emission), float16_t(2.0/15.0), float16_t(1.0)); // TODO: we should just add to the lighting in deferred instead of multiplying the color

			#ifdef HAND
				data |= 0x80000000u; // set most significant bit to 1
			#endif
		#endif

		colortex2.g = data;
	}

	#ifdef TERRAIN
		immut float16_t avg_luma = float16_t(bitfieldExtract(v_tbn.handedness_and_misc, 5, 13)) * float16_t(1.0/8191.0);
	#else
		const float16_t avg_luma = float16_t(0.8);
	#endif

	{
		#if defined SM && defined MC_SPECULAR_MAP
			float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
		#else
			float16_t roughness = gen_roughness(luma, avg_luma);
		#endif

		const float16_t sss = float16_t(0.0); // TODO: labPBR SSS map support

		uint data = packUnorm4x8(f16vec4(roughness, sss, 0.0, 0.0));

		#ifndef NETHER
			data = bitfieldInsert(
				data,
				packUnorm2x16(f16vec2(v.s_screen.x, 0.0)),
				16, 16
			);
		#endif

		colortex2.b = data;
	}

	#ifndef NETHER
		colortex2.a = packUnorm2x16(v.s_screen.yz);
	#endif

	#ifdef TERRAIN
		immut float16_t in_ao = float16_t(v.ao);

		float16_t ao = mix(
			smoothstep(float16_t(0.05), float16_t(0.8), in_ao),
			float16_t(1.0),
			float16_t(0.25)
		) * mix(in_ao, float16_t(1.0), float16_t(0.75));
	#else
		float16_t ao = float16_t(0.9);
	#endif

	ao = saturate(fma(luma - avg_luma, float16_t(0.5), ao)); // TODO: make the multiplier here a configurable value

	// TODO: labPBR AO map support

	colortex1 = f16vec4(color.rgb, float16_t(ao));
}
