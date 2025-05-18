#include "/prelude/core.glsl"

/* RENDERTARGETS: 1,2,3 */
layout(location = 0) out vec4 colortex1; // layout(location = 0) out f16vec4 colortex1; // does this work outside of NVIDIA drivers?
layout(location = 1) out uvec2 colortex2;

#ifndef NETHER
	layout(location = 2) out vec3 colortex3;
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

	#ifndef NETHER
		colortex3 = v.s_screen;
	#endif

	immut f16vec3 tint = f16vec3(v.tint);
	color.rgb *= tint;

	#ifdef NO_NORMAL
		immut vec3 normal = mat3(gbufferModelViewInverse) * vec3(0.0, 0.0, 1.0);
		immut vec3 tangent = mat3(gbufferModelViewInverse) * vec3(0.0, 1.0, 0.0);
		immut mat3 tbn = mat3(tangent, cross(tangent, normal), normal);
	#else
		immut mat3 tbn = get_tbn();
	#endif

	#if (NORMALS != 2 && !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)) || !(SM && defined MC_SPECULAR_MAP)
		immut float16_t luma = luminance(color.rgb);
	#endif

	#if defined NO_NORMAL || NORMALS == 2
		immut f16vec3 w_tex_normal = f16vec3(tbn[2]);
	#elif NORMALS == 1 && defined MC_NORMAL_MAP
		immut f16vec3 w_tex_normal = f16vec3(tbn * sample_normal(texture(normals, v.coord).rg));
	#else
		immut f16vec3 w_tex_normal = f16vec3(tbn * gen_normal(gtexture, tint, v.coord, v.mid_coord, v.face_tex_size, luma));

		/*
		immut ivec2 half_texels = ivec2(
			v.face_tex_size & 65535u,
			bitfieldExtract(v.face_tex_size, 16, 16)
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

	immut uint packed_normal = packSnorm4x8(f16vec4(
		octa_encode(w_tex_normal),
		octa_encode(f16vec3(tbn[2])) // todo!() just pass through octa normal when "Flat" normals are used
	));

	#ifdef TERRAIN
		immut float16_t in_ao = float16_t(v.ao);
		immut float16_t ao = mix(
			smoothstep(float16_t(0.05), float16_t(0.8), in_ao),
			float16_t(1.0),
			float16_t(0.25)
		) * mix(in_ao, float16_t(1.0), float16_t(0.75));

		f16vec2 light = ao * f16vec2(v.light.x, fma(in_ao, float16_t(AMBIENT), float16_t(v.light.y)));
	#else
		f16vec2 light = f16vec2(v.light.x, v.light.y + AMBIENT);
	#endif

	// we have to min() after conversion here because of float16_t precision at these high values
	immut uvec2 scaled_light = min(uvec2(fma(light, f16vec2(8191.0), f16vec2(0.5))), 8191u);

	uint packed_light_and_emission_and_hand = bitfieldInsert(scaled_light.x, scaled_light.y, 13, 13);

	#if defined TERRAIN || defined HAND
		immut uint emission = bitfieldExtract(v_tbn.handedness_and_misc, 1, 4);
		packed_light_and_emission_and_hand = bitfieldInsert(packed_light_and_emission_and_hand, emission, 26, 4);

		#ifdef HAND
			packed_light_and_emission_and_hand |= 0x80000000u; // set most significant bit to 1
		#endif
	#endif

	colortex2 = uvec2(packed_normal, packed_light_and_emission_and_hand);

	#if SM && defined MC_SPECULAR_MAP
		float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
	#else
		#ifdef TERRAIN
			immut float16_t avg_luma = float16_t(bitfieldExtract(v_tbn.handedness_and_misc, 5, 13)) * float16_t(1.0/8191.0);
		#else
			const float16_t avg_luma = float16_t(0.8);
		#endif

		float16_t roughness = gen_roughness(luma, avg_luma);
	#endif

	colortex1 = vec4(linear(color.rgb), roughness);
}
