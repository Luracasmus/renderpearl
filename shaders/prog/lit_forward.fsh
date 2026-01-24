#include "/prelude/core.glsl"

#ifdef DEFERRED_IGNORE
	/* RENDERTARGETS: 1,2 */
	#ifdef NETHER
		layout(location = 1) out uint colortex2;
	#else
		layout(location = 1, component = 1) out uint colortex2;
	#endif
#else
	/* RENDERTARGETS: 1 */
#endif

#ifdef TRANSLUCENT
	layout(location = 0) out f16vec4 colortex1;
#else
	layout(location = 0) out f16vec3 colortex1;
#endif

#ifdef ALPHA_CHECK
	layout(depth_greater) out float gl_FragDepth;

	uniform float alphaTestRef;
#else
	layout(depth_unchanged) out float gl_FragDepth;
#endif

#include "/lib/mmul.glsl"
#include "/lib/brdf.glsl"
#include "/lib/mv_inv.glsl"
uniform mat4 gbufferProjectionInverse;
uniform sampler2D gtexture;

#ifdef NO_NORMAL
	uniform mat3 normalMatrix;
#else
	#include "/lib/octa_normal.glsl"
#endif

in
#include "/lib/lit_v_data.glsl"

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

	#include "/lib/skylight.glsl"
	#include "/lib/sm/distort.glsl"
	#include "/lib/light/shadows.glsl"
#endif

#include "/lib/view_size.glsl"
#include "/lib/luminance.glsl"
#include "/lib/srgb.glsl"
#define SKY_FSH
#include "/lib/fog.glsl"
#include "/lib/material/specular.glsl"
#include "/lib/material/ao.glsl"
#include "/lib/light/non_block.glsl"
#include "/lib/light/sample_ll_block.glsl"

readonly
#include "/buf/ll.glsl"
uniform vec3 cameraPositionFract;

#ifndef NO_NORMAL
	#include "/lib/material/normal.glsl"
#endif

#if HAND_LIGHT != 0
	readonly
	#include "/buf/hl.glsl"

	#include "/lib/light/hand.glsl"
#endif

void main() {
	// TODO: Fix strange tint.
	// TODO: Fix procedural normals.

	#if defined TRANSLUCENT || defined ALPHA_CHECK
		f16vec4 color = f16vec4(texture(gtexture, v.coord));
	#else
		f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);
	#endif

	#ifdef ALPHA_CHECK
		immut bool will_discard = color.a < float16_t(alphaTestRef);

		#ifdef SUBGROUP_ENABLED
			if (subgroupAll(will_discard)) { discard; }
		#endif
	#else
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
	immut float16_t avg_srgb_luma = unpackFloat2x16(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma).y;

	#if defined SM && defined MC_SPECULAR_MAP
		immut float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
	#else
		immut float16_t roughness = gen_roughness(srgb_luma, avg_srgb_luma);
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
			immut float16_t handedness = fma(float16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 4, 1)), float16_t(-2.0), float16_t(1.0));

			immut mat3 w_tbn = mat3(w_face_tangent, vec3(cross(w_face_tangent, w_face_normal) * handedness), w_face_normal);

			#if NORMALS == 1 && defined MC_NORMAL_MAP
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * sample_normal(texture(normals, v.coord).rg));
			#else
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * gen_normal(gtexture, tint, v.coord, v.unorm2x16_mid_coord, v.uint2x16_face_tex_size, srgb_luma));
			#endif
		#endif
	#endif

	color.rgb = linear(color.rgb);
	immut f16vec3 rcp_color = float16_t(1.0) / max(color.rgb, float16_t(1.0e-5));

	vec3 ndc = fma(vec3(gl_FragCoord.xy / vec2(view_size()), gl_FragCoord.z), vec3(2.0), vec3(-1.0));
	#ifdef HAND
		ndc.z /= MC_HAND_DEPTH;
	#endif
	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 pe = MV_INV * view;
	immut f16vec3 n_pe = f16vec3(normalize(pe));
	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	f16vec3 light = f16vec3(0.0);

	immut f16vec2 block_sky_light =
		#ifdef TERRAIN
			f16vec2(v.light);
		#else
			unpackFloat2x16(v.float2x16_light);
		#endif

	#ifdef TERRAIN
		float16_t ao = corner_ao_curve(v.ao);
	#else
		float16_t ao = float16_t(0.9);
	#endif

	#if DIR_SHADING != 0
		ao *= dir_shading(w_tex_normal);
	#endif

	ao *= gen_tex_ao(srgb_luma, avg_srgb_luma); // TODO: labPBR AO.

	immut bool is_maybe_ll_lit = (
		block_sky_light.x != float16_t(0.0) && chebyshev_dist < float16_t(LL_DIST) && !will_discard && !gl_HelperInvocation
	);

	#ifdef LIGHT_LEVELS
		f16vec3 block_light = f16vec3(visualize_ll(block_sky_light.x));
	#else
		f16vec3 block_light = block_sky_light.x * f16vec3(BL_FALLBACK_R, BL_FALLBACK_G, BL_FALLBACK_B);
	#endif

	#if HAND_LIGHT != 0
		immut float16_t ind_bl = float16_t(IND_BL) * ao;
	#endif

	if (subgroupAny(is_maybe_ll_lit)) {
		#ifdef DEFERRED_IGNORE
			colortex2 = colortex2_g_deferred_ignore;
		#endif

		#if HAND_LIGHT == 0
			immut float16_t ind_bl = float16_t(IND_BL) * ao;
		#endif

		f16vec3 lit_max_pe, lit_max_view, lit_min_pe, lit_min_view;
		if (is_maybe_ll_lit) {
			lit_max_pe = f16vec3(pe);
			lit_max_view = f16vec3(view);

			lit_min_pe = lit_max_pe;
			lit_min_view = lit_max_view;
		} else { // We don't want unlit or helper invocations making the bounding boxes bigger but we still need them to be active.
			#ifdef FLOAT16
				const float16_t minus_inf = uint16BitsToFloat16(uint16_t(0xFC00u));
				const float16_t inf = uint16BitsToFloat16(uint16_t(0x7C00u));
			#else
				const float minus_inf = uintBitsToFloat(0xFF800000u);
				const float inf = uintBitsToFloat(0x7F800000u);
			#endif

			lit_max_pe = minus_inf.xxx;
			lit_max_view = minus_inf.xxx;

			lit_min_pe = inf.xxx;
			lit_min_view = inf.xxx;
		}

		immut f16vec3 chunk_pe_min = f16vec3(subgroupMin(lit_min_pe));
		immut f16vec3 chunk_pe_max = f16vec3(subgroupMax(lit_max_pe));

		immut f16vec3 chunk_view_min = f16vec3(subgroupMin(lit_min_view));
		immut f16vec3 chunk_view_max = f16vec3(subgroupMax(lit_max_view));

		immut f16vec3 ll_offset = f16vec3(vec3(-255.5) + subgroupBroadcastFirst(ll.offset) - cameraPositionFract - mvInv3);
		immut uint16_t global_len = uint16_t(subgroupBroadcastFirst(ll.len));

		immut uvec4 chunk_ballot = subgroupBallot(true);
		// const uint16_t sg_size = uint16_t(gl_SubgroupSize);
		immut uint16_t chunk_invs = uint16_t(subgroupBallotBitCount(chunk_ballot));
		immut uint16_t chunk_inv_id = uint16_t(gl_SubgroupInvocationID) - uint16_t(subgroupBallotFindLSB(chunk_ballot));

		f16vec3 diffuse = f16vec3(0.0);
		f16vec3 specular = f16vec3(0.0);

		for (uint16_t chunk_i = uint16_t(0u); chunk_i < global_len; chunk_i += chunk_invs) {
			bool inv_is_in_bb;
			float16_t inv_light_offset_intensity;
			f16vec3 inv_pe_light;
			f16vec3 inv_light_color;
			bool inv_is_wide;

			// Check if light is inside the subgroup bounding boxes.
			immut uint16_t collab_inv_i = chunk_i + chunk_inv_id;

			if (collab_inv_i < global_len) {
				immut uint light_data = ll.data[collab_inv_i];

				inv_pe_light = f16vec3(
					light_data & 511u,
					bitfieldExtract(light_data, 9, 9),
					bitfieldExtract(light_data, 18, 9)
				) + ll_offset;

				// We add '0.5' to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
				inv_light_offset_intensity = float16_t(bitfieldExtract(light_data, 27, 4)) + float16_t(0.5);

				// Distance between light and closest point on bounding box.
				// In world-aligned space (player-eye) we can use Manhattan distance.
				immut float16_t mhtn_dist_from_pe_bb = dot(abs(inv_pe_light - clamp(inv_pe_light, chunk_pe_min, chunk_pe_max)), f16vec3(1.0));

				inv_is_in_bb = mhtn_dist_from_pe_bb <= inv_light_offset_intensity;

				if (inv_is_in_bb) {
					immut f16vec3 v_light = f16vec3(inv_pe_light * MV_INV);
					immut float16_t euclid_dist_from_view_bb = distance(v_light, clamp(v_light, chunk_view_min, chunk_view_max));

					inv_is_in_bb = euclid_dist_from_view_bb <= inv_light_offset_intensity;
					// TODO: Maybe check for when the light is closer than the size of the bounding box, meaning it will be applying to all invocations.

					if (inv_is_in_bb) {
						inv_is_wide = light_data >= 0x80000000u;

						#ifdef INT16
							immut uint16_t packed_light_color = ll.color[collab_inv_i];
							inv_light_color = f16vec3(
								(packed_light_color >> uint16_t(6u)) & uint16_t(31u),
								packed_light_color & uint16_t(63u),
								(packed_light_color >> uint16_t(11u))
							);
						#else
							immut uint packed_light_color = bitfieldExtract(ll.color[collab_inv_i/2u], int(16u * (collab_inv_i & 1u)), 16);
							inv_light_color = f16vec3(
								bitfieldExtract(uint(packed_light_color), 6, 5),
								packed_light_color & uint16_t(63u),
								(packed_light_color >> uint16_t(11u))
							);
						#endif
					}
				}
			} else {
				inv_is_in_bb = false;
			}

			if (subgroupAny(inv_is_in_bb)) {
				immut uvec4 in_bb_ballot = subgroupBallot(inv_is_in_bb);
				immut uint16_t lsb = uint16_t(subgroupBallotFindLSB(in_bb_ballot));
				immut uint16_t msb = uint16_t(subgroupBallotFindMSB(in_bb_ballot));

				// Now we actually check the lights per invocation, skipping the ones which are outside the BBs.

				for (uint16_t i = lsb; i <= msb; ++i) {
					if (subgroupBallotBitExtract(in_bb_ballot, i)) { // This is always true when `i == lsb` or `i == msb`.
						immut float16_t offset_intensity = float16_t(subgroupBroadcast(inv_light_offset_intensity, i));
						immut f16vec3 pe_light = f16vec3(subgroupBroadcast(inv_pe_light, i));
						immut bool is_wide = subgroupBroadcast(inv_is_wide, i);
						f16vec3 light_color = f16vec3(subgroupBroadcast(inv_light_color, i));

						if (is_maybe_ll_lit) {
							immut f16vec3 w_rel_light = f16vec3(vec3(pe_light) - pe);

							immut float16_t mhtn_dist = dot(abs(w_rel_light), f16vec3(1.0));

							if (mhtn_dist < offset_intensity) {
								sample_ll_block_light(
									specular, diffuse,
									offset_intensity - float16_t(0.5), offset_intensity,
									w_tex_normal, w_face_normal, n_pe,
									roughness, ind_bl,
									w_rel_light, mhtn_dist, light_color, is_wide
								);
							}
						}
					}
				}
			}
		}

		block_light = mix_ll_block_light(block_light, chebyshev_dist, block_sky_light.x, specular, diffuse, rcp_color);
	}

	// We probably want to have everything in this that doesn't require derivatives or SG stuff.
	// I think (?) it should usually be slightly faster.
	if (!gl_HelperInvocation) {
		#ifdef ALPHA_CHECK
			if (will_discard) { discard; } else
		#endif
		{
			light += block_light;

			#ifdef TRANSLUCENT
				immut uint16_t packed_alpha = uint16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 5, 11));
				color.a *= float16_t(1.0/2047.0) * float16_t(packed_alpha);
			#endif

			#ifdef NETHER
				const f16vec3 sky_light_color = f16vec3(0.0);
			#else
				immut f16vec3 sky_light_color = skylight();
			#endif

			light += ao * non_block_light(sky_light_color, block_sky_light.y);

			#ifndef NETHER
				immut f16vec3 n_w_shadow_light = f16vec3(shadowLightDirectionPlr);

				#ifdef NO_NORMAL
					const float16_t face_n_dot_l = float16_t(1.0);
					const float16_t tex_n_dot_l = float16_t(1.0);
				#else
					immut float16_t face_n_dot_l = dot(w_face_normal, n_w_shadow_light);
					immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_shadow_light);
				#endif

				sample_shadow(
					light,
					chebyshev_dist, v.s_distortion,
					sky_light_color, rcp_color, roughness,
					face_n_dot_l, tex_n_dot_l, n_w_shadow_light,
					w_tex_normal, n_pe, pe
				);
			#endif

			#if HAND_LIGHT != 0
				if (handLightPackedLR != 0) {
					const bool is_hand = (
						#ifdef HAND
							true
						#else
							false
						#endif
					);

					immut u16vec2 hand_light_lr = unpackUint2x16(uint(handLightPackedLR));
					immut bvec2 active_lr = notEqual(hand_light_lr, u16vec2(0u));

					if (active_lr.x) {
						light += get_hand_light(hand_light_lr.x, subgroupBroadcastFirst(hl.unorm11_11_10_left), f16vec3(-0.2, -0.2, -0.1), view, pe, n_pe, roughness, w_tex_normal, w_face_normal, rcp_color, ind_bl, is_hand);
					}

					if (active_lr.y) {
						light += get_hand_light(hand_light_lr.y, subgroupBroadcastFirst(hl.unorm11_11_10_right), f16vec3(0.2, -0.2, -0.1), view, pe, n_pe, roughness, w_tex_normal, w_face_normal, rcp_color, ind_bl, is_hand);
					}
				}
			#endif

			color.rgb *= light;

			#ifdef TRANSLUCENT
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
			#else
				#ifdef NETHER
					immut f16vec3 srgb_fog_col = f16vec3(fogColor);
				#elif defined END
					immut f16vec3 srgb_fog_col = srgb(sky(n_pe));
				#else
					immut float16_t sky_fog_val = sky_fog(float16_t(n_pe.y));
					immut f16vec3 srgb_fog_col = srgb(sky(sky_fog_val, n_pe, sunDirectionPlr));
				#endif

				color.rgb = linear(mix(srgb(color.rgb), srgb_fog_col, vanilla_fog(pe)));

				colortex1 = color.rgb;
			#endif
		}
	}
}
