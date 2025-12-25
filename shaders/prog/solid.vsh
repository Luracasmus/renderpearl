#include "/prelude/core.glsl"

#ifdef EMISSIVE_REDSTONE_BLOCK
#endif
#ifdef EMISSIVE_EMERALD_BLOCK
#endif
#ifdef EMISSIVE_LAPIS_BLOCK
#endif

out gl_PerVertex { vec4 gl_Position; };

#include "/lib/mv_inv.glsl"
uniform float farSquared;
uniform vec3 cameraPositionFract;
uniform mat4 modelViewMatrix, projectionMatrix, textureMatrix;

#ifndef NETHER
	uniform vec3 shadowLightDirectionPlr;
	uniform mat4 shadowModelView;

	#include "/lib/sm/distort.glsl"
	#include "/lib/sm/bias.glsl"
#endif

// #if defined TERRAIN || (HAND_LIGHT && defined HAND) || (NORMALS != 2 && !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP))
	uniform sampler2D gtexture;
// #endif // TODO

#ifdef HAND
	uniform int handLightPackedLR;

	#if HAND_LIGHT
		#include "/buf/hand_light.glsl"
	#endif
#endif

#ifdef TERRAIN
	#include "/buf/ll.glsl"

	uniform bool rebuildLL;
	uniform vec3 cameraPosition, chunkOffset;

	in vec2 mc_Entity;
	in vec4 at_midBlock;

	#include "/lib/prng/pcg.glsl"

	#if WAVES && defined SOLID_TERRAIN
		#include "/lib/waves/offset.glsl"
	#endif
#endif

#ifdef ENTITY_COLOR
	uniform vec4 entityColor;
#endif

// #if defined TERRAIN || (HAND_LIGHT && defined HAND) || (NORMALS != 2 && !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP))
	in vec2 mc_midTexCoord;
// #endif

in vec2 vaUV0;
in vec3 vaPosition;
in vec4 vaColor;

#ifndef NO_NORMAL
	uniform mat3 normalMatrix;

	#include "/lib/tbn/vsh.glsl"
#endif

out VertexData {
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

#include "/lib/mmul.glsl"
#include "/lib/luminance.glsl"
#include "/lib/srgb.glsl"
#include "/lib/norm_uv2.glsl"

void main() {
	vec3 model = vaPosition;

	#ifdef TERRAIN
		model += chunkOffset;

		#if WAVES && defined SOLID_TERRAIN
			if (mc_Entity.y == 1.0) { model.y += wave(model.xz); }
		#endif
	#endif

	if (dot(model.xz, model.xz) < farSquared) {
		immut vec3 view = rot_trans_mmul(modelViewMatrix, model);
		immut vec4 clip = proj_mmul(projectionMatrix, view);
		gl_Position = clip;

		v.coord = rot_trans_mmul(textureMatrix, vaUV0);
		v.light = norm_uv2();

		f16vec3 color = f16vec3(vaColor.rgb);
		#ifdef ENTITY_COLOR
			color = mix(color, f16vec3(entityColor.rgb), float16_t(entityColor.a));
		#endif
		v.tint = vec3(color);

		immut vec3 pe = MV_INV * view;
		immut f16vec3 abs_pe = abs(f16vec3(pe));
		immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

		#ifndef NO_NORMAL
			immut mat3 normal_model_view_inverse = MV_INV * normalMatrix;
			immut f16vec3 w_normal = f16vec3(normal_model_view_inverse * normalize(vaNormal));
			immut f16vec3 w_tangent = f16vec3(normal_model_view_inverse * normalize(at_tangent.xyz));

			init_tbn(w_normal, w_tangent); // this must run before writing to `v_tbn.handedness_and_misc`

			#if NORMALS != 2 && !(NORMALS == 1 && defined MC_NORMAL_MAP)
				immut u16vec2 texels = u16vec2(fma(abs(v.coord - mc_midTexCoord), vec2(2 * textureSize(gtexture, 0)), vec2(0.5)));
				v.face_tex_size = packUint2x16(texels);
				v.mid_coord = packUnorm2x16(mc_midTexCoord);
			#endif

			#ifdef HAND
				immut bool is_right = view.x > 0.0;
				immut u16vec2 hand_light_lr = unpackUint2x16(uint(handLightPackedLR));
				immut uint16_t this_hand_light = is_right ? hand_light_lr.y : hand_light_lr.x;
				v_tbn.handedness_and_misc = bitfieldInsert(v_tbn.handedness_and_misc, this_hand_light, 1, 4);

				#if HAND_LIGHT
					if (this_hand_light != uint16_t(0u) && abs(view.x) > 0.3) { // Use a margin around the center to not register e.g. a swinging sword as being on the opposite side.
						// Scale and round to fit packing.
						immut u16vec3 scaled_color = u16vec3(fma(
							linear(v.tint * f16vec3(textureLod(gtexture, mix(v.coord, mc_midTexCoord, 0.5), 3.0).rgb)),
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
			#elif defined TERRAIN
				v.ao = vaColor.a;

				// #if !(defined SM && defined MC_SPECULAR_MAP)
					immut f16vec3 avg_col = color * f16vec3(textureLod(gtexture, mc_midTexCoord, 4.0).rgb);
					immut uint scaled_avg_luma = uint(fma(luminance(avg_col), float16_t(8191.0), float16_t(0.5)));
					v_tbn.handedness_and_misc = bitfieldInsert(v_tbn.handedness_and_misc, scaled_avg_luma, 5, 13);
				// #endif

				float16_t norm_emission = min((max(float16_t(mc_Entity.x), float16_t(0.0)) + float16_t(at_midBlock.w)) / float16_t(15.0), float16_t(1.0));
				v.light.x = min(fma(float16_t(norm_emission), float16_t(0.3), max(v.light.x, norm_emission)), float16_t(1.0));

				immut uint emission = uint(fma(norm_emission, float16_t(15.0), float16_t(0.5))); // bring into 4-bit-representable range and round
				v_tbn.handedness_and_misc = bitfieldInsert(v_tbn.handedness_and_misc, emission, 1, 4);

				// Only rebuild the index once every LL_RATE frames, and cull chunks which completely outside LL_DIST in Chebyshev distance in uniform control flow.
				if (rebuildLL && max3(chunkOffset.x, chunkOffset.y, chunkOffset.z) < float(LL_DIST + 16)) {
					immut f16vec3 view_f16 = f16vec3(view);

					if (
						// Run once per face.
						(gl_VertexID & 3) == 1 && // gl_VertexID % 4 == 1
						// Cull too weak or non-lights.
						emission >= MIN_LL_INTENSITY &&
						// Cull vertices outside LL_DIST using Chebyshev distance.
						chebyshev_dist < float16_t(LL_DIST) &&
						// Cull behind camera outside of illumination range.
						(view_f16.z < float16_t(0.0) || dot(abs_pe, f16vec3(1.0)) <= float16_t(emission))
					) {
						immut bool fluid = mc_Entity.y == 1.0;
						immut uvec3 seed = uvec3(ivec3(0.5 + cameraPosition + pe));

						// LOD culling
						// Increase times two each LOD.
						// The fact that the values resulting from higher LODs are divisible by the lower ones means that no lights will appear only further away.
						if (uint8_t(pcg(seed.x + pcg(seed.y + pcg(seed.z)))) % (uint8_t(1u) << uint8_t(min(7.0, fma(
							(fluid ? float16_t(LAVA_LOD_BIAS) : float16_t(0.0)) + length(view_f16) / float16_t(LL_DIST),
							float16_t(LOD_FALLOFF),
							float16_t(0.5)
						)))) == uint8_t(0u)) {
							immut uvec3 light_pe = uvec3(clamp(fma(at_midBlock.xyz, vec3(1.0/64.0), 256.0 + pe + cameraPositionFract), 0.0, 511.5)); // This feels slightly cursed but it works. // somehow
							immut uint packed_pe = bitfieldInsert(bitfieldInsert(light_pe.x, light_pe.y, 9, 9), light_pe.z, 18, 9);

							#ifdef SUBGROUP_ENABLED
								// Deduplicate lights within the subgroup before pushing to the global list.
								bool is_unique = true;

								uvec4 sg_ballot = subgroupBallot(true);
								immut uint shuffles = subgroupBallotFindMSB(sg_ballot) - subgroupBallotFindLSB(sg_ballot);

								// We want to shuffle through all active invocations.
								for (uint i = 1u; i <= shuffles; ++i) {
									immut uint other_packed_pe = subgroupShuffleDown(packed_pe, i);

									// If the invocation who's value we've aquired is within the subgroup and active...
									if ((gl_SubgroupInvocationID + i < gl_SubgroupSize) && subgroupBallotBitExtract(sg_ballot, gl_SubgroupInvocationID + i)) {
										// ...and has the same light position as we do, remove our light.
										if (other_packed_pe == packed_pe) {
											is_unique = false;
											break;
										}
									}

									sg_ballot = subgroupBallot(true);
								}

								if (is_unique)
							#endif
							{
								#ifdef SM
									#ifdef MC_SPECULAR_MAP
										immut f16vec3 avg_col = f16vec3(textureLod(gtexture, mc_midTexCoord, 4.0).rgb);
									#endif
								#endif

								#define SG_INCR_COUNTER ll.queue
								uint sg_incr_i;
								#include "/lib/sg_incr.glsl"

								uint light_data = bitfieldInsert(
									packed_pe, // Position.
									emission, 27, 4 // Intensity.
								);
								if (fluid) light_data |= 0x80000000u; // Set "wide" flag for lava.

								ll.data[sg_incr_i] = light_data;

								immut f16vec3 scaled_color = fma(linear(color * avg_col), f16vec3(31.0, 63.0, 31.0), f16vec3(0.5));

								#ifdef INT16
									ll.color[sg_incr_i] = uint16_t(scaled_color.g) | (uint16_t(scaled_color.r) << uint16_t(6u)) | (uint16_t(scaled_color.b) << uint16_t(11u));
								#else
									immut uvec3 uint_color = uvec3(scaled_color);
									ll.color[sg_incr_i] = bitfieldInsert(bitfieldInsert(uint_color.g, uint_color.r, 6, 5), uint_color.b, 11, 5);
								#endif
							}
						}
					}
				}
			#endif
		#endif

		#ifndef NETHER
			if (chebyshev_dist < float16_t(shadowDistance * shadowDistanceRenderMul)) {
				#ifdef NO_NORMAL
					immut f16vec3 w_normal = f16vec3(mvInv2); // == f16vec3(MV_INV * vec3(0.0, 0.0, 1.0))
				#endif

				// TODO: This bias is better than before but it would probably be best to do it in shadow screen space and offset a scaled amount of texels.
				immut f16vec2 bias = shadow_bias(dot(w_normal, f16vec3(shadowLightDirectionPlr)));

				vec3 s_ndc = shadow_proj_scale * (mat3(shadowModelView) * rot_trans_mmul(mat4(mat4x3(mvInv0, mvInv1, mvInv2, mvInv3)), view));
				s_ndc.xy = distort(s_ndc.xy);

				s_ndc = fma(mat3(shadowModelView) * vec3(bias.y * w_normal), shadow_proj_scale, s_ndc);
				// s_ndc.z += float(bias.x); // Doesn't really seem to help :/

				v.s_screen = fma(s_ndc, vec3(0.5), vec3(0.5));
			}
		#endif
	} else {
		gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
	}
}
