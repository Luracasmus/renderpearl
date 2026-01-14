#include "/prelude/core.glsl"

#ifdef EMISSIVE_REDSTONE_BLOCK
#endif
#ifdef EMISSIVE_EMERALD_BLOCK
#endif
#ifdef EMISSIVE_LAPIS_BLOCK
#endif
#ifdef SM
#endif

out gl_PerVertex { vec4 gl_Position; };

#include "/lib/mv_inv.glsl"
uniform float farSquared;
uniform mat4 modelViewMatrix, projectionMatrix, textureMatrix;

// TODO: Handle these better:
in vec2 mc_midTexCoord;
uniform sampler2D gtexture;

#ifndef NETHER
	uniform vec3 shadowLightDirectionPlr;
	uniform mat4 shadowModelView;

	#include "/lib/sm/distort.glsl"
	#include "/lib/sm/bias.glsl"
#endif

#ifdef HAND
	uniform int handLightPackedLR;

	#if HAND_LIGHT
		#include "/buf/hand_light.glsl"
	#endif
#endif

#ifdef TERRAIN
	#include "/buf/llq.glsl"

	uniform bool rebuildLLQ;
	uniform vec3 cameraPosition, cameraPositionFract, chunkOffset;
	// `mc_chunkFade` is patched in by Iris.

	in vec2 mc_Entity;
	in vec4 at_midBlock;

	#include "/lib/prng/pcg.glsl"

	#if defined TRANSLUCENT || (WAVES != 0 && defined SOLID_TERRAIN)
		#include "/lib/waves/offset.glsl"
	#endif
#endif

#ifdef ENTITY_COLOR
	uniform vec4 entityColor;
#endif

in vec2 vaUV0;
in vec3 vaPosition;
in vec4 vaColor;

#ifndef NO_NORMAL
	uniform mat3 normalMatrix;
	in vec3 vaNormal;
	in vec4 at_tangent;

	#include "/lib/octa_normal.glsl"
#endif

out
#include "/lib/lit_v_data.glsl"

#include "/lib/mmul.glsl"
#include "/lib/luminance.glsl"
#include "/lib/srgb.glsl"
#include "/lib/norm_uv2.glsl"

void main() {
	vec3 model = vaPosition;

	#ifdef TERRAIN
		model += chunkOffset;

		#if defined TRANSLUCENT || (WAVES != 0 && defined SOLID_TERRAIN)
			immut bool fluid = mc_Entity.y == 1.0;
			if (fluid) { model.y += wave(model.xz); }
		#endif
	#endif

	if (dot(model.xz, model.xz) < farSquared) {
		immut vec3 view = rot_trans_mmul(modelViewMatrix, model);
		immut vec4 clip = proj_mmul(projectionMatrix, view);
		gl_Position = clip;

		v.coord = rot_trans_mmul(textureMatrix, vaUV0);

		immut vec3 pe = MV_INV * view;
		immut f16vec3 abs_pe = abs(f16vec3(pe));
		immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

		#ifdef NO_NORMAL
			immut f16vec3 w_normal = f16vec3(mvInv2); // == MV_INV * vec3(0.0, 0.0, 1.0)
		#else
			immut mat3 normal_model_view_inverse = MV_INV * normalMatrix;
			immut f16vec3 w_normal = f16vec3(normal_model_view_inverse * normalize(vaNormal));
			immut f16vec3 w_tangent = f16vec3(normal_model_view_inverse * normalize(at_tangent.xyz));

			v.snorm4x8_octa_tangent_normal = packSnorm4x8(f16vec4(octa_encode(w_tangent), octa_encode(w_normal)));

			#if NORMALS != 2 && !(NORMALS == 1 && defined MC_NORMAL_MAP)
				immut u16vec2 texels = u16vec2(fma(abs(v.coord - mc_midTexCoord), vec2(2 * textureSize(gtexture, 0)), vec2(0.5)));
				v.uint2x16_face_tex_size = packUint2x16(texels);
				v.unorm2x16_mid_coord = packUnorm2x16(mc_midTexCoord);
			#endif

			// Pack handedness.
			// We mask away everything except the sign (highest) bit and shift it down to index 4.
			v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma |= (floatBitsToUint(at_tangent.w) & 2147483648u) >> 28u;
		#endif

		f16vec3 color = f16vec3(vaColor.rgb);
		#ifdef ENTITY_COLOR
			color = mix(color, f16vec3(entityColor.rgb), float16_t(entityColor.a));
		#endif
		immut f16vec3 avg_col = color * f16vec3(textureLod(gtexture, mc_midTexCoord, 4.0).rgb);
		immut float16_t avg_luma = luminance(avg_col);
		v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma = packFloat2x16(f16vec2(float16_t(0.0), avg_luma));

		#ifdef TERRAIN
			v.tint = vec3(color);
			v.ao = vaColor.a;
			immut float16_t ao = float16_t(v.ao);

			immut float16_t emission = max(float16_t(mc_Entity.x), float16_t(at_midBlock.w));
			v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma |= uint(emission + float16_t(0.5));
			// float16_t norm_emission = min(emission / float16_t(15.0), float16_t(1.0));
			// v.light.x = float(min(fma(float16_t(norm_emission), float16_t(0.3), max(float16_t(v.light.x), norm_emission)), float16_t(1.0)));

			float alpha = mc_chunkFade;

			#ifdef TRANSLUCENT
				if (fluid) {
					alpha *= float16_t(WATER_OPACITY * 0.01);
				}
			#endif

			// Only rebuild the index once every LL_RATE frames, and cull chunks which are completely outside LL_DIST in Chebyshev distance in uniform control flow.
			if (rebuildLLQ && max3(chunkOffset.x, chunkOffset.y, chunkOffset.z) < float(LL_DIST + 16)) {
				immut f16vec3 view_f16 = f16vec3(view);

				#if !(WAVES != 0 && defined SOLID_TERRAIN)
					immut bool fluid = mc_Entity.y == 1.0;
				#endif

				if (
					// Run once per face.
					(gl_VertexID & 3) == 1 && // gl_VertexID % 4 == 1
					// Cull too weak or non-lights.
					emission >= float16_t(MIN_LL_INTENSITY) &&
					// Cull vertices outside LL_DIST using Chebyshev distance.
					chebyshev_dist < float16_t(LL_DIST) &&
					// Cull behind camera outside of illumination range.
					(view_f16.z < float16_t(0.0) || dot(abs_pe, f16vec3(1.0)) <= emission)
				) {
					immut uvec3 seed = uvec3(ivec3((0.5 + cameraPosition) + pe));

					// LOD culling
					// Increase times two each LOD.
					// The fact that the values resulting from higher LODs are divisible by the lower ones means that no lights will appear only further away.
					if (uint8_t(pcg(seed.x + pcg(seed.y + pcg(seed.z)))) % (uint8_t(1u) << uint8_t(min(float16_t(7.0), fma(
						(fluid ? float16_t(LAVA_LOD_BIAS) : float16_t(0.0)) + length(view_f16) / float16_t(LL_DIST),
						float16_t(LOD_FALLOFF),
						float16_t(0.5)
					)))) == uint8_t(0u)) {
						immut vec3 pf = pe + mvInv3;
						immut uvec3 offset_floor_pf = clamp(uvec3(fma(at_midBlock.xyz, vec3(1.0/64.0), 255.5 + cameraPositionFract + pf)), 0u, 511u);
						immut uint packed_pf = bitfieldInsert(bitfieldInsert(offset_floor_pf.x, offset_floor_pf.y, 9, 9), offset_floor_pf.z, 18, 9);

						immut f16vec3 scaled_color = fma(linear(avg_col), f16vec3(31.0, 63.0, 31.0), f16vec3(0.5));

						#ifdef INT16
							immut uint16_t packed_color = uint16_t(scaled_color.g) | (uint16_t(scaled_color.r) << uint16_t(6u)) | (uint16_t(scaled_color.b) << uint16_t(11u));
						#else
							immut uvec3 uint_color = uvec3(scaled_color);
							immut uint16_t packed_color = uint16_t(bitfieldInsert(bitfieldInsert(uint_color.g, uint_color.r, 6, 5), uint_color.b, 11, 5));
						#endif

						#ifdef SUBGROUP_ENABLED
							// Deduplicate lights within the subgroup before pushing to the global list.
							bool is_unique = true;

							uvec4 sg_ballot = subgroupBallot(true);
							uint shuffles = subgroupBallotFindMSB(sg_ballot) - subgroupBallotFindLSB(sg_ballot);

							// Shuffle down through all active invocations.
							for (uint i = 1u; i <= shuffles; ++i) {
								immut uint other_packed_pf = subgroupShuffleDown(packed_pf, i);
								immut uint16_t other_packed_color = uint16_t(subgroupShuffleDown(packed_color, i));

								// If the invocation who's value we've aquired is within the subgroup and active
								// and has the same light position as we do and greater than or equal color value, remove our light.
								immut uint other_sg_invoc_id = gl_SubgroupInvocationID + i;
								if (
									(other_sg_invoc_id < gl_SubgroupSize) &&
									subgroupBallotBitExtract(sg_ballot, other_sg_invoc_id) &&
									other_packed_pf == packed_pf &&
									other_packed_color >= packed_color
								) {
									is_unique = false;
								}
							}

							if (is_unique) {
								sg_ballot = subgroupBallot(true);
								shuffles = subgroupBallotFindMSB(sg_ballot) - subgroupBallotFindLSB(sg_ballot);

								// Shuffle up through all remaining invocations.
								for (uint i = 1u; i <= shuffles; ++i) {
									immut uint other_packed_pf = subgroupShuffleUp(packed_pf, i);

									// We know that if an invocation with the same position at a lower index is still active,
									// that means it has a greater color value, so we remove our light.
									if (
										(gl_SubgroupInvocationID >= i) &&
										subgroupBallotBitExtract(sg_ballot, gl_SubgroupInvocationID - i) &&
										other_packed_pf == packed_pf
									) {
										is_unique = false;
									}
								}

								if (is_unique)
						#endif
								{
									#define SG_INCR_COUNTER llq.len
									uint sg_incr_i;
									#include "/lib/sg_incr.glsl"

									uint packed_data = bitfieldInsert(
										packed_pf, // Position.
										v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 27, 4 // Intensity from emission.
									);
									if (fluid) { packed_data |= 0x80000000u; } // Set "wide" flag for lava.

									llq.data[sg_incr_i] = packed_data;
									llq.color[sg_incr_i] = packed_color;
								}
						#ifdef SUBGROUP_ENABLED
							}
						#endif
					}
				}
			}
		#else
			const float16_t ao = float16_t(1.0);

			#ifdef TRANSLUCENT
				immut float16_t alpha = float16_t(vaColor.a);
			#endif

			v.unorm4x8_tint_zero = packUnorm4x8(f16vec4(color, 0.0));

			#ifdef HAND
				immut bool is_right = view.x > 0.0;
				immut u16vec2 hand_light_lr = unpackUint2x16(uint(handLightPackedLR));
				immut uint16_t this_hand_light = is_right ? hand_light_lr.y : hand_light_lr.x;
				v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma |= uint(this_hand_light);

				#if HAND_LIGHT
					if (this_hand_light != uint16_t(0u) && abs(view.x) > 0.3) { // Use a margin around the center to not register e.g. a swinging sword as being on the opposite side.
						// Scale and round to fit packing.
						immut u16vec3 scaled_color = u16vec3(fma(
							linear(color * f16vec3(textureLod(gtexture, mix(v.coord, mc_midTexCoord, 0.5), 3.0).rgb)),
							f16vec3(hand_light_pack_scale),
							f16vec3(0.5)
						));

						uint rg = packUint2x16(scaled_color.rg);
						uint b_count = packUint2x16(u16vec2(scaled_color.g, uint16_t(1u))); // The second component is just 1, to count the number of times we're adding to the sum.

						if (is_right) {
							#ifdef SUBGROUP_ENABLED
								rg = subgroupAdd(rg);
								b_count = subgroupAdd(b_count);

								if (subgroupElect())
							#endif
							{
								atomicAdd(hand_light.right.x, rg);
								atomicAdd(hand_light.right.y, b_count);
							}
						} else {
							#ifdef SUBGROUP_ENABLED
								rg = subgroupAdd(rg);
								b_count = subgroupAdd(b_count);

								if (subgroupElect())
							#endif
							{
								atomicAdd(hand_light.left.x, rg);
								atomicAdd(hand_light.left.y, b_count);
							}
						}
					}
				#endif
			#endif
		#endif

		#if defined TERRAIN || defined TRANSLUCENT
			v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma = bitfieldInsert(
				v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma,
				uint(fma(alpha, 2047.0, 0.5)), // Scale and round from (0.0, 1.0] to [0, 2047].
				5, 11
			); // Pack alpha.
		#endif

		#ifdef TERRAIN
			v.light = vec2(norm_uv2());
		#else
			v.float2x16_light = packFloat2x16(norm_uv2());
		#endif

		#ifndef NETHER
			if (chebyshev_dist < float16_t(shadowDistance * shadowDistanceRenderMul)) {
				#ifdef NO_NORMAL
					immut f16vec3 w_normal = f16vec3(mvInv2); // == f16vec3(MV_INV * vec3(0.0, 0.0, 1.0))
				#endif

				// TODO: This bias is better than before but it would probably be best to do it in shadow screen space and offset a scaled amount of texels.
				immut f16vec2 bias = shadow_bias(dot(w_normal, f16vec3(shadowLightDirectionPlr)));

				vec3 s_ndc = shadow_proj_scale * (mat3(shadowModelView) * rot_trans_mmul(mat4(mat4x3(mvInv0, mvInv1, mvInv2, mvInv3)), view));
				s_ndc.xy *= distortion(s_ndc.xy);

				s_ndc = fma(mat3(shadowModelView) * vec3(bias.y * w_normal), shadow_proj_scale, s_ndc);
				// s_ndc.z += float(bias.x); // Doesn't really seem to help :/

				v.s_screen = fma(s_ndc, vec3(0.5), vec3(0.5));
			}
		#endif
	} else {
		gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
	}
}
