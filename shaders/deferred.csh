#include "/prelude/core.glsl"

/* Deferred Lighting */

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

readonly
#include "/buf/ll.glsl"

#include "/lib/mv_inv.glsl"
uniform vec3 cameraPositionFract;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D depthtex0;
uniform usampler2D colortex2;
uniform layout(rgba16f) restrict image2D colorimg1;

#ifdef END
	uniform float endFlashIntensity;
#endif

#include "/lib/mmul.glsl"
#include "/lib/view_size.glsl"
#include "/lib/luminance.glsl"
#include "/lib/octa_normal.glsl"
#include "/lib/skylight.glsl"
#include "/lib/srgb.glsl"
#include "/lib/brdf.glsl"
#include "/lib/light/non_block.glsl"
#include "/lib/light/sample_ll_block.glsl"

#ifndef NETHER
	uniform vec3 shadowLightDirectionPlr;
	uniform mat4 shadowModelView;
	uniform float frameTimeCounter;

	#include "/lib/prng/pcg.glsl"

	#ifdef END
		#include "/lib/prng/fast_rand.glsl"
	#else
		uniform vec3 sunDirectionPlr;
	#endif

	#include "/lib/light/shadows.glsl"
#endif

#include "/lib/fog.glsl"

#ifdef LIGHT_LEVELS
	#include "/lib/llv.glsl"
#endif

const uint local_index_size = uint(float(LL_CAPACITY) * LDS_RATIO);

shared struct {
	ivec3 bb_pe_min;
	ivec3 bb_pe_max;
	ivec3 bb_view_min;
	uint index_len;
	ivec3 bb_view_max;
	uint[local_index_size] ll_data;
	uint16_t[local_index_size] ll_color;
} sh;

#if HAND_LIGHT != 0
	readonly
	#include "/buf/hl.glsl"

	#include "/lib/light/hand.glsl"
#endif

void main() {
	// TODO: Look into skipping light list stuff if the entire work group is unlit.

	if (gl_LocalInvocationIndex == 0u) {
		sh.index_len = 0u;

		const ivec3 i32_max = ivec3(0x7fffffff);
		const ivec3 i32_min = ivec3(0x80000000);

		sh.bb_pe_min = i32_max;
		sh.bb_pe_max = i32_min;
		sh.bb_view_min = i32_max;
		sh.bb_view_max = i32_min;
	}

	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);
	immut float depth = texelFetch(depthtex0, texel, 0).r;
	immut bool is_geo = depth < 1.0;

	uvec3 gbuf_gba;
	f16vec3 color;
	float16_t block_light_level;

	if (is_geo) {
		gbuf_gba = (
			#ifdef NETHER
				texelFetch(colortex2, texel, 0).rgb
			#else
				texelFetch(colortex2, texel, 0).gba
			#endif
		);

		immut f16vec4 color_block_light = f16vec4(imageLoad(colorimg1, texel));
		color = color_block_light.rgb;
		block_light_level = color_block_light.a;
	} else {
		gbuf_gba.xy = uvec2(0u);
	}

	immut vec2 texel_size = 1.0 / vec2(view_size());
	immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
	vec3 ndc = fma(vec3(coord, depth), vec3(2.0), vec3(-1.0));

	immut bool is_hand = gbuf_gba.y >= 0x80000000u; // The most significant bit being 1 indicates hand.
	if (is_hand) { ndc.z /= MC_HAND_DEPTH; }

	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 pe = MV_INV * view;

	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	immut bool is_maybe_block_lit = is_geo && block_light_level != float16_t(0.0) && chebyshev_dist < float16_t(LL_DIST);

	barrier();

	if (is_maybe_block_lit) { // Calculate view and player-eye space bounding boxes for the work group.
		#ifdef SUBGROUP_ENABLED
			immut vec3 sg_pe_min = subgroupMin(pe);
			immut vec3 sg_pe_max = subgroupMax(pe);

			immut vec3 sg_view_min = subgroupMin(view);
			immut vec3 sg_view_max = subgroupMax(view);

			if (subgroupElect()) {
				immut ivec3 floor_sg_pe_min = ivec3(sg_pe_min - 0.5);
				immut ivec3 ceil_sg_pe_max = ivec3(sg_pe_max + 0.5);

				atomicMin(sh.bb_pe_min.x, floor_sg_pe_min.x); atomicMax(sh.bb_pe_max.x, ceil_sg_pe_max.x);
				atomicMin(sh.bb_pe_min.y, floor_sg_pe_min.y); atomicMax(sh.bb_pe_max.y, ceil_sg_pe_max.y);
				atomicMin(sh.bb_pe_min.z, floor_sg_pe_min.z); atomicMax(sh.bb_pe_max.z, ceil_sg_pe_max.z);

				immut ivec3 floor_sg_view_min = ivec3(sg_view_min - 0.5);
				immut ivec3 ceil_sg_view_max = ivec3(sg_view_max + 0.5);

				atomicMin(sh.bb_view_min.x, floor_sg_view_min.x); atomicMax(sh.bb_view_max.x, ceil_sg_view_max.x);
				atomicMin(sh.bb_view_min.y, floor_sg_view_min.y); atomicMax(sh.bb_view_max.y, ceil_sg_view_max.y);
				atomicMin(sh.bb_view_min.z, floor_sg_view_min.z); atomicMax(sh.bb_view_max.z, ceil_sg_view_max.z);
			}
		#else
			immut ivec3 ceil_pe = ivec3(pe + 0.5);
			immut ivec3 floor_pe = ivec3(pe - 0.5);

			atomicMin(sh.bb_pe_min.x, floor_pe.x); atomicMax(sh.bb_pe_max.x, ceil_pe.x);
			atomicMin(sh.bb_pe_min.y, floor_pe.y); atomicMax(sh.bb_pe_max.y, ceil_pe.y);
			atomicMin(sh.bb_pe_min.z, floor_pe.z); atomicMax(sh.bb_pe_max.z, ceil_pe.z);

			immut ivec3 ceil_view = ivec3(view + 0.5);
			immut ivec3 floor_view = ivec3(view - 0.5);

			atomicMin(sh.bb_view_min.x, floor_view.x); atomicMax(sh.bb_view_max.x, ceil_view.x);
			atomicMin(sh.bb_view_min.y, floor_view.y); atomicMax(sh.bb_view_max.y, ceil_view.y);
			atomicMin(sh.bb_view_min.z, floor_view.z); atomicMax(sh.bb_view_max.z, ceil_view.z);
		#endif
	}

	barrier();

	immut f16vec3 bb_pe_min = f16vec3(subgroupBroadcastFirst(sh.bb_pe_min));
	immut f16vec3 bb_pe_max = f16vec3(subgroupBroadcastFirst(sh.bb_pe_max));

	vec3 index_offset = vec3(-255.5);

	// Make sure this tile isn't fully unlit, out of range or sky by checking if the player-eye bounding box has non-negative dimensions.
	// This branch must be taken the same way by the whole work group for the barrier within to be safe.
	if (all(greaterThanEqual(bb_pe_max, bb_pe_min))) {
		index_offset += subgroupBroadcastFirst(ll.offset) - cameraPositionFract - mvInv3;

		immut f16vec3 bb_view_min = f16vec3(subgroupBroadcastFirst(sh.bb_view_min));
		immut f16vec3 bb_view_max = f16vec3(subgroupBroadcastFirst(sh.bb_view_max));

		immut uint16_t global_len = uint16_t(subgroupBroadcastFirst(ll.len));
		for (uint16_t i = uint16_t(gl_LocalInvocationIndex); i < global_len; i += uint16_t(gl_WorkGroupSize.x * gl_WorkGroupSize.y)) {
			immut uint light_data = ll.data[i];

			immut f16vec3 pe_light = f16vec3(
				light_data & 511u,
				bitfieldExtract(light_data, 9, 9),
				bitfieldExtract(light_data, 18, 9)
			) + f16vec3(index_offset);

			// Add '0.5' to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
			immut float16_t offset_intensity = float16_t(bitfieldExtract(light_data.x, 27, 4)) + float16_t(0.5);

			// Distance between light and closest point on bounding box.
			// In world-aligned space (player-eye) we can use Manhattan distance.
			immut float16_t light_mhtn_dist_from_bb = dot(abs(pe_light - clamp(pe_light, bb_pe_min, bb_pe_max)), f16vec3(1.0));
			immut bool pe_visible = light_mhtn_dist_from_bb <= offset_intensity; // not sure why this +1 is needed here

			immut f16vec3 v_light = f16vec3(pe_light * MV_INV);
			immut bool view_visible = distance(v_light, clamp(v_light, bb_view_min, bb_view_max)) <= offset_intensity;

			if (pe_visible && view_visible) {
				#define SG_INCR_COUNTER sh.index_len
				uint sg_incr_i;
				#include "/lib/sg_incr.glsl"

				sh.ll_data[sg_incr_i] = light_data;

				#ifdef INT16
					sh.ll_color[sg_incr_i] = ll.color[i];
				#else
					sh.ll_color[sg_incr_i] = bitfieldExtract(ll.color[i/2u], int(16u * (i & 1u)), 16);
				#endif
			}
		}

		barrier(); // This control flow is safe since it's guaranteed to be the same across the work group.
	}

	immut uint8_t f0_enum = uint8_t(gbuf_gba.x >> 24u);

	if (f0_enum != uint8_t(230u)) { // Exit on "deferred ignore" flag.
		immut f16vec3 n_pe = f16vec3(normalize(pe));

		#ifdef NETHER
			const f16vec3 sky_light_color = f16vec3(0.0);
			immut f16vec3 srgb_fog_color = f16vec3(fogColor);
		#else
			immut f16vec3 sky_light_color = skylight();

			#ifdef END
				immut f16vec3 fog_color = sky(n_pe);
			#else
				immut float16_t sky_fog_val = sky_fog(float16_t(n_pe.y));
				immut f16vec3 fog_color = sky(sky_fog_val, n_pe, sunDirectionPlr);
			#endif
		#endif

		if (is_geo) {
			immut f16vec3 roughness_sss_emissiveness = f16vec3(unpackUnorm4x8(gbuf_gba.x).rgb);
			immut float16_t roughness = roughness_sss_emissiveness.x;
			immut float16_t sss = roughness_sss_emissiveness.y;
			immut float16_t emissiveness = roughness_sss_emissiveness.z;

			immut float16_t sky_light_level = uint16BitsToFloat16(uint16_t(gbuf_gba.y) & uint16_t(32767u));
			immut float16_t ao = float16_t(1.0/8191.0) * float16_t(uint16_t(bitfieldExtract(gbuf_gba.y, 15, 13)));

			immut f16vec4 octa_normal = f16vec4(unpackSnorm4x8(gbuf_gba.z));
			immut f16vec3 w_tex_normal = normalize(octa_decode(octa_normal.xy));
			immut f16vec3 w_face_normal = normalize(octa_decode(octa_normal.zw));

			#ifdef LIGHT_LEVELS
				f16vec3 block_light = f16vec3(visualize_ll(block_light_level));
			#else
				f16vec3 block_light = block_light_level * f16vec3(BL_FALLBACK_R, BL_FALLBACK_G, BL_FALLBACK_B);
			#endif

			immut f16vec3 rcp_color = float16_t(1.0) / max(color, float16_t(1.0e-4));

			#if HAND_LIGHT != 0
				immut float16_t ind_bl = float16_t(IND_BL) * ao;
			#endif

			if (is_maybe_block_lit) {
				#if HAND_LIGHT == 0
					immut float16_t ind_bl = float16_t(IND_BL) * ao;
				#endif

				immut vec3 offset = vec3(index_offset) - pe;

				f16vec3 diffuse = f16vec3(0.0);
				f16vec3 specular = f16vec3(0.0);

				immut uint16_t index_len = uint16_t(subgroupBroadcastFirst(sh.index_len));
				for (uint16_t i = uint16_t(0u); i < index_len; ++i) {
					immut uint light_data = subgroupBroadcastFirst(sh.ll_data[i]);

					immut f16vec3 w_rel_light = f16vec3(vec3(
						light_data & 511u,
						bitfieldExtract(light_data, 9, 9),
						bitfieldExtract(light_data, 18, 9)
					) + offset);

					immut float16_t intensity = float16_t(bitfieldExtract(light_data.x, 27, 4));
					immut float16_t offset_intensity = intensity + float16_t(0.5);
					immut float16_t mhtn_dist = dot(abs(w_rel_light), f16vec3(1.0));

					if (mhtn_dist < offset_intensity) { // We add '0.5' to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
						immut bool is_wide = light_data >= 0x80000000u;

						immut uint16_t packed_light_color = uint16_t(subgroupBroadcastFirst(sh.ll_color[i]));

						#ifdef INT16
							immut f16vec3 light_color = f16vec3(
								(packed_light_color >> uint16_t(6u)) & uint16_t(31u),
								packed_light_color & uint16_t(63u),
								(packed_light_color >> uint16_t(11u))
							);
						#else
							immut f16vec3 light_color = f16vec3(
								bitfieldExtract(uint(packed_light_color), 6, 5),
								packed_light_color & uint16_t(63u),
								(packed_light_color >> uint16_t(11u))
							);
						#endif

						sample_ll_block_light(
							specular, diffuse,
							intensity, offset_intensity,
							w_tex_normal, w_face_normal, n_pe,
							roughness, ind_bl,
							w_rel_light, mhtn_dist, light_color, is_wide
						);
					}
				}

				block_light = mix_ll_block_light(block_light, chebyshev_dist, block_light_level, specular, diffuse, rcp_color);
			} // else block_light = f16vec3(1.0); // DEBUG: `is_maybe_block_lit`

			// DEBUG: Culling & LDS overflow.
			// block_light.gb += f16vec2(sh.index_len < ll.len, sh.index_len == 0);
			// block_light.rgb += distance(max(float16_t(sh.bb_view_min), float16_t(0.0)), max(float16_t(sh.bb_view_max), float16_t(0.0))) * float16_t(0.01);
			// if (sh.index_len > local_index_size) block_light *= 10;

			f16vec3 light = float16_t(EMISSIVE_BRIGHTNESS) * emissiveness + ao * non_block_light(sky_light_color, sky_light_level) + block_light;
			// TODO: Something is making emissive blocks way brighter that is not this. We should look into it.

			#if HAND_LIGHT != 0
				if (handLightPackedLR != 0) {
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

			#ifndef NETHER
				immut f16vec3 n_w_shadow_light = f16vec3(shadowLightDirectionPlr);
				immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_shadow_light);
				immut float16_t face_n_dot_l = dot(w_face_normal, n_w_shadow_light);

				immut float s_distortion = uintBitsToFloat(texelFetch(colortex2, texel, 0).r); // TODO: Maybe we should move this inside the branch in `sample_shadow`.
				sample_shadow(
					light,
					chebyshev_dist, s_distortion,
					sky_light_color, rcp_color, roughness,
					face_n_dot_l, tex_n_dot_l, n_w_shadow_light,
					w_tex_normal, n_pe, pe
				);
			#endif

			color *= light;

			#ifndef NETHER
				immut f16vec3 srgb_fog_color = srgb(fog_color);
			#endif

			color = linear(mix(srgb(color), srgb_fog_color, vanilla_fog(pe)));
		} else { // Render sky.
			#if defined NETHER || defined END
				#ifdef NETHER
					immut f16vec3 fog_color = linear(srgb_fog_color);
				#endif

				color = fog_color;
			#else
				immut uvec2 seed = uvec2(ivec2(n_pe.xz * 1000.0 + sin(frameTimeCounter * 1000.0) * 0.2));

				immut float16_t stars = max(
					float16_t(1.0) - sky_fog_val - float16_t(skyState.x),
					float16_t(0.0)
				) * smoothstep(
					float16_t(0.9995),
					float16_t(1.0),
					float16_t(
						float(pcg(seed.x + pcg(seed.y))) / float(0xFFFFFFFFu)
					)
				);

				color = stars + fog_color;

				immut vec3 sun_abs_dist = abs(n_pe - sunDirectionPlr);
				immut bool sun = max3(sun_abs_dist.x, sun_abs_dist.y, sun_abs_dist.z) < SUN_SIZE;
				immut bool moon = all(lessThan(abs(n_pe + sunDirectionPlr), fma(skyState.z, MOON_PHASE_DIFF, MOON_SIZE).xxx));

				if (sun || moon) {
					color += sky_light_color;
				}
			#endif
		}

		imageStore(colorimg1, texel, vec4(color, 0.0));
	}
}
