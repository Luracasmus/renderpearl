#if NORMALS == 1 && defined MC_NORMAL_MAP
	uniform sampler2D normals;

	vec3 sample_normal(vec2 nm) {
		return normalize(fma(vec3(nm.xy, sqrt(1.0 - dot(nm.xy, nm.xy))), vec3(2.0), vec3(-1.0)));
	}
#elif NORMALS != 2
	// Alpha-checked sRGB -> luma conversion that falls back to zero
	float16_t srgbl_a_ck(f16vec4 color, f16vec3 tint) {
		#ifdef ALPHA_CHECK
			return (color.a > float16_t(alphaTestRef)) ? luminance(tint * color.rgb) : float16_t(0.0);
		#else
			return luminance(tint * color.rgb);
		#endif
	}

	vec3 gen_normal(sampler2D source, f16vec3 tint, vec2 coord, uint mid_coord, uint face_tex_size, float16_t srgb_luma) {
		const float scale = 0.55;
		const float16_t texel_bump = float16_t(0.5);
		const float16_t subtexel_bump = float16_t(0.5);
		const float subtexel_scale = 0.075;

		immut vec2 local_coord = coord - unpackUnorm2x16(mid_coord);

		immut ivec2 half_texels = ivec2(
			face_tex_size & 65535u,
			bitfieldExtract(face_tex_size, 16, 16)
		) / (2 << int(textureQueryLod(source, coord).x + 0.5)) - 1;

		f16vec4 bump = srgb_luma.xxxx;

		immut vec2 atlas = vec2(textureSize(source, 0));
		immut ivec2 local_texel = ivec2(local_coord * atlas);

		const ivec2[4] offsets = ivec2[4](
			ivec2(-1, 0),
			ivec2(1, 0),
			ivec2(0, -1),
			ivec2(0, 1)
		);
		immut vec2 offset_coord = coord + 0.5/atlas; // this is necessary because... it doesn't work otherwise ¯\_(ツ)_/¯
		immut mat4 nbh = transpose(mat4(
			textureGatherOffsets(source, offset_coord, offsets, 0),
			textureGatherOffsets(source, offset_coord, offsets, 1),
			textureGatherOffsets(source, offset_coord, offsets, 2),
			textureGatherOffsets(source, offset_coord, offsets, 3)
		));
		bump = mix(bump, f16vec4(
			srgbl_a_ck(f16vec4(nbh[0]), tint),
			srgbl_a_ck(f16vec4(nbh[1]), tint),
			srgbl_a_ck(f16vec4(nbh[2]), tint),
			srgbl_a_ck(f16vec4(nbh[3]), tint)
		), texel_bump * f16vec4(
			local_texel.x > -half_texels.x,
			local_texel.x < half_texels.x,
			local_texel.y > -half_texels.y,
			local_texel.y < half_texels.y
		)); // todo!() disable this on empty hand

		immut vec2 atlas_texel = 1.0 / atlas;
		immut vec2 subtexel = subtexel_scale * atlas_texel;
		immut vec2 half_size = vec2(half_texels) * atlas_texel;
		bump = mix(bump, f16vec4(
			srgbl_a_ck(f16vec4(texture(source, vec2(coord.x - subtexel.x, coord.y))), tint),
			srgbl_a_ck(f16vec4(texture(source, vec2(coord.x + subtexel.x, coord.y))), tint),
			srgbl_a_ck(f16vec4(texture(source, vec2(coord.x, coord.y - subtexel.y))), tint),
			srgbl_a_ck(f16vec4(texture(source, vec2(coord.x, coord.y + subtexel.y))), tint)
		), subtexel_bump * f16vec4(
			local_coord.x > -half_size.x,
			local_coord.x < half_size.x,
			local_coord.y > -half_size.y,
			local_coord.y < half_size.y
		));

		// Thanks to: https://stackoverflow.com/a/5284527/21652346
		return normalize(cross(normalize(vec3(scale, 0.0, bump.y - bump.x)), normalize(vec3(0.0, scale, bump.w - bump.z))));
	}
#endif
