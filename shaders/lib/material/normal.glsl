#if NORMALS == 1 && defined MC_NORMAL_MAP
	uniform sampler2D normals;

	vec3 sample_normal(vec2 nm) { // TODO: `float16_t`
		nm = fma(nm, vec2(2.0), vec2(-1.0));
		return vec3(nm, sqrt(1.0 - dot(nm, nm)));
	}
#elif NORMALS != 2
	// Alpha-checked sRGB -> luma conversion that falls back to zero.
	float16_t srgbl_a_ck(f16vec4 srgb_color, f16vec3 srgb_tint) {
		#ifdef ALPHA_CHECK
			return (srgb_color.a > float16_t(alphaTestRef)) ? luminance(srgb_tint * srgb_color.rgb) : float16_t(0.0);
		#else
			return luminance(srgb_tint * srgb_color.rgb);
		#endif
	}

	vec3 gen_normal(sampler2D srgb_source, f16vec3 srgb_tint, vec2 coord, uint unorm2x16_mid_coord, uint uint2x16_face_tex_size, float16_t srgb_luma) {
		const float16_t scale = float16_t(1.1); // TODO: make this configurable

		immut vec2 local_coord = coord - unpackUnorm2x16(unorm2x16_mid_coord);
		immut ivec2 local_texel = ivec2(local_coord * vec2(textureSize(srgb_source, 0)));

		immut float lod = textureQueryLod(srgb_source, coord).x;
		immut ivec2 half_texels = ivec2(unpackUint2x16(
			uint2x16_face_tex_size
		) / uint16_t(2u << uint16_t(ceil(lod))) - uint16_t(1u));

		immut f16vec4 bump = f16vec4(
			local_texel.x > -half_texels.x ? srgbl_a_ck(f16vec4(textureOffset(srgb_source, coord, ivec2(-1, 0))), srgb_tint) : srgb_luma,
			local_texel.x < half_texels.x ? srgbl_a_ck(f16vec4(textureOffset(srgb_source, coord, ivec2(1, 0))), srgb_tint) : srgb_luma,
			local_texel.y > -half_texels.y ? srgbl_a_ck(f16vec4(textureOffset(srgb_source, coord, ivec2(0, -1))), srgb_tint) : srgb_luma,
			local_texel.y < half_texels.y ? srgbl_a_ck(f16vec4(textureOffset(srgb_source, coord, ivec2(0, 1))), srgb_tint) : srgb_luma
		);

		// Thanks to: https://stackoverflow.com/a/5284527/21652346
		return cross(
			normalize(f16vec3(scale, float16_t(0.0), bump.y - bump.x)),
			normalize(f16vec3(float16_t(0.0), scale, bump.w - bump.z))
		);
	}
#endif
