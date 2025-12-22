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
#endif

#include "/lib/mmul.glsl"
#include "/lib/view_size.glsl"
#include "/lib/luminance.glsl"
#include "/lib/octa_normal.glsl"
#include "/lib/skylight.glsl"
#include "/lib/sm/shadows.glsl"
#include "/lib/srgb.glsl"
#include "/lib/fog.glsl"
// #include "/lib/u16_unpack3.glsl"

#ifdef LIGHT_LEVELS
	#include "/lib/llv.glsl"
#endif

const uint local_index_size = uint(float(LL_CAPACITY) * LDS_RATIO);

struct Shared {
	ivec3 bb_pe_min;
	ivec3 bb_pe_max;
	ivec3 bb_view_min;
	uint index_len;
	ivec3 bb_view_max;
	uint[local_index_size] index_data;
	uint16_t[local_index_size] index_color;
}; shared Shared sh;

#if HAND_LIGHT != 0
	readonly
	#include "/buf/hand_light.glsl"

	uniform int handLightPackedLR;
	uniform mat4 gbufferProjection;
	uniform sampler2D depthtex2;

	f16vec3 get_hand_light(uint16_t light_level, uvec2 buf_data, vec3 origin_view, vec3 view, vec3 pe, f16vec3 n_pe, float16_t roughness, f16vec3 w_tex_normal, f16vec3 w_face_normal, f16vec3 rcp_color, float16_t ind_bl, bool is_hand) {
		immut f16vec3 pe_to_light = MV_INV * origin_view - pe;
		immut float16_t sq_dist = dot(pe_to_light, pe_to_light);
		immut f16vec3 n_w_rel_light = pe_to_light * inversesqrt(sq_dist);

		immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_rel_light);

		immut u16vec2 rg = unpackUint2x16(buf_data.x);
		immut u16vec2 b_count = unpackUint2x16(buf_data.y);
		immut f16vec3 illum = float16_t(light_level) * float16_t(float(HAND_LIGHT) / hand_light_pack_scale) / max(float16_t(b_count.y) * sq_dist, float16_t(0.0078125)) * f16vec3(rg, b_count.x);

		f16vec3 light;

		if (min(tex_n_dot_l, dot(w_face_normal, n_w_rel_light)) > float16_t(0.0)) {
			#define MAX_HAND_LIGHT_TRACE_DIST 64 // temp/todo
			#define HAND_LIGHT_TRACE_STEPS 32

			float16_t dir_bl;

			const float trace_dist = float(MAX_HAND_LIGHT_TRACE_DIST);
			if (sq_dist < trace_dist*trace_dist && !is_hand) { // Ray trace if not hand and within tracing range.
				f16vec4 from = proj_mmul(gbufferProjection, origin_view);
				f16vec4 to = proj_mmul(gbufferProjection, view);

				// Do multiplication part of ndc -> screen out here.
				from.xyz *= float16_t(0.5);
				to.xyz *= float16_t(0.5);

				immut f16vec4 step = (to - from) / float(HAND_LIGHT_TRACE_STEPS + 1);
				f16vec4 ray_halfclip = from;

				float16_t visibility = float16_t(HAND_LIGHT_TRACE_STEPS);

				for (uint i = 0u; i < uint(HAND_LIGHT_TRACE_STEPS); ++i) {
					ray_halfclip += step;

					immut f16vec2 ray_screen_undiv_xy = fma(ray_halfclip.ww, f16vec2(0.5), ray_halfclip.xy);
					// immut ivec2 texel = ivec2(ray_screen.xy * view_size());

					// immut vec4 depth_samples = textureGather(depthtex2, trace_screen.xy, 0);
					// immut bvec4 visible_samples = greaterThan(trace_screen.zzzz, depth_samples); // step just doesn't work here on AMD Mesa for some reason

					immut float sampled = textureProjLod(depthtex2, vec3(ray_screen_undiv_xy, ray_halfclip.w), 0.0).r;

					visibility -= float16_t((sampled - 0.5) * ray_halfclip.w < ray_halfclip.z);
				}

				if (visibility <= float16_t(HAND_LIGHT_TRACE_STEPS) * float16_t(0.5)) { // Adjust this to make shadows soft or hard
					return ind_bl * illum;
				}

				visibility /= float(HAND_LIGHT_TRACE_STEPS);
				dir_bl = visibility*visibility*visibility*visibility*visibility;
			} else {
				dir_bl = float16_t(1.0);
			}

			immut f16vec2 specular_diffuse = dir_bl * brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, roughness);

			light = fma(specular_diffuse.xxx, rcp_color, (specular_diffuse.y + ind_bl).xxx);
		} else {
			light = ind_bl.xxx;
		}

		return light * illum;
	}
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
	immut uvec4 gbuf = is_geo ? texelFetch(colortex2, texel, 0) : uvec4(0u);

	immut vec2 texel_size = 1.0 / vec2(view_size());
	immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
	vec3 ndc = fma(vec3(coord, depth), vec3(2.0), vec3(-1.0));

	immut bool is_hand = gbuf.y >= 0x80000000u; // The most significant bit being 1 indicates hand.
	if (is_hand) { ndc.z /= MC_HAND_DEPTH; }

	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 pe = MV_INV * view;

	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	// Check if block light (first 15 bits) isn't zero, and we're within LL_DIST.
	immut bool is_lit = (gbuf.y & 32767u) != 0u && chebyshev_dist < float16_t(LL_DIST);

	barrier();

	if (is_lit) { // Calculate view and player-eye space bounding boxes for the work group.
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

	immut f16vec3 bb_pe_min = f16vec3(sh.bb_pe_min);
	immut f16vec3 bb_pe_max = f16vec3(sh.bb_pe_max);

	vec3 index_offset = vec3(-255.5);

	if (all(greaterThanEqual(bb_pe_max, bb_pe_min))) { // Make sure this tile isn't fully unlit, out of range or sky.
		index_offset += ll.offset - cameraPositionFract - mvInv3;

		immut f16vec3 bb_view_min = f16vec3(sh.bb_view_min);
		immut f16vec3 bb_view_max = f16vec3(sh.bb_view_max);

		immut uint16_t global_len = uint16_t(ll.len);
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
				immut uint j = atomicAdd(sh.index_len, 1u);

				sh.index_data[j] = light_data;
				sh.index_color[j] = ll.color[i];
			}
		}
	}

	barrier();

	if (bitfieldExtract(gbuf.y, 30, 1) == 0u) { // Exit on "pure light" flag.
		immut f16vec3 n_pe = f16vec3(normalize(pe));

		#ifdef NETHER
			immut f16vec3 fog_col = linear(f16vec3(fogColor));
		#elif defined END
			immut f16vec3 fog_col = sky(n_pe);
		#else
			immut float16_t sky_fog_val = sky_fog(float16_t(n_pe.y));
			immut f16vec3 fog_col = sky(sky_fog_val, n_pe, sunDirectionPlr);

			immut f16vec3 skylight_color = skylight();
		#endif

		f16vec3 color;

		if (is_geo) {
			immut f16vec4 color_ao = f16vec4(imageLoad(colorimg1, texel));

			immut f16vec2 roughness_sss = f16vec2(unpackUnorm4x8(gbuf.z).xy);

			immut f16vec4 octa_normal = f16vec4(unpackSnorm4x8(gbuf.x));
			immut f16vec3 w_tex_normal = normalize(octa_decode(octa_normal.xy));
			immut f16vec3 w_face_normal = normalize(octa_decode(octa_normal.zw));

			immut f16vec2 light = f16vec2(vec2(
				gbuf.y & 32767u,
				bitfieldExtract(gbuf.y, 15, 15)
			) / 32767.0);

			#ifdef LIGHT_LEVELS
				f16vec3 block_light = f16vec3(visualize_ll(light.x));
			#else
				f16vec3 block_light = light.x * f16vec3(BL_FALLBACK_R, BL_FALLBACK_G, BL_FALLBACK_B);
			#endif

			immut f16vec3 rcp_color = float16_t(1.0) / max(color_ao.rgb, float16_t(1.0e-4));

			#if HAND_LIGHT != 0
				immut float16_t ind_bl = float16_t(IND_BL) * color_ao.a;
			#endif

			if (is_lit) {
				#if HAND_LIGHT == 0
					immut float16_t ind_bl = float16_t(IND_BL) * color_ao.a;
				#endif

				immut vec3 offset = vec3(index_offset) - pe;

				f16vec3 diffuse = f16vec3(0.0);
				f16vec3 specular = f16vec3(0.0);

				immut uint16_t index_len = uint16_t(sh.index_len);
				for (uint16_t i = uint16_t(0u); i < index_len; ++i) {
					immut uint light_data = sh.index_data[i];

					immut f16vec3 w_rel_light = f16vec3(vec3(
						light_data & 511u,
						bitfieldExtract(light_data, 9, 9),
						bitfieldExtract(light_data, 18, 9)
					) + offset);

					immut float16_t intensity = float16_t(bitfieldExtract(light_data.x, 27, 4));
					immut float16_t mhtn_dist = dot(abs(w_rel_light), f16vec3(1.0));

					if (mhtn_dist < intensity + float16_t(0.5)) {
						immut uint16_t light_color = sh.index_color[i];

						immut float16_t sq_dist_light = dot(w_rel_light, w_rel_light);
						immut f16vec3 n_w_rel_light = w_rel_light * inversesqrt(sq_dist_light);

						// Make falloff start a block away of the light source when the "wide" flag (most significant bit) is set.
						immut float16_t falloff = float16_t(1.0) / (
							light_data >= 0x80000000u ? max(sq_dist_light - float16_t(1.0), float16_t(1.0)) : sq_dist_light
						);

						immut float16_t light_level = intensity - mhtn_dist + float16_t(0.5);
						float16_t brightness = intensity * falloff;
						brightness *= smoothstep(float16_t(0.0), float16_t(LL_FALLOFF_MARGIN), light_level);
						brightness /= min(light_level, float16_t(15.0)) * float16_t(1.0/15.0); // Compensate for multiplication with 'light.x' later on, in order to make the falloff follow the inverse square law as much as possible.
						brightness = min(brightness, float16_t(48.0)); // Prevent `float16_t` overflow later on.

						#ifdef INT16
							immut f16vec3 illum = brightness * f16vec3(
								(light_color >> uint16_t(6u)) & uint16_t(31u),
								light_color & uint16_t(63u),
								(light_color >> uint16_t(11u))
							);
						#else
							immut f16vec3 illum = brightness * f16vec3(
								bitfieldExtract(uint(light_color), 6, 5),
								light_color & uint16_t(63u),
								(light_color >> uint16_t(11u))
							);
						#endif

						immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_rel_light);

						float16_t light_diffuse = ind_bl; // Very fake GI.

						if (min(tex_n_dot_l, dot(w_face_normal, n_w_rel_light)) > float16_t(0.0)) {
							immut f16vec2 specular_diffuse = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, roughness_sss.r);
							specular = fma(specular_diffuse.xxx, illum, specular);
							light_diffuse += specular_diffuse.y;
						}

						diffuse = fma(light_diffuse.xxx, illum, diffuse);
					}
				}

				// Undo the multiplication from packing light color and brightness.
				const vec3 packing_scale = vec3(15u * uvec3(31u, 63u, 31u));
				immut f16vec3 new_light = f16vec3(float(DIR_BL * 3) / packing_scale) * light.x * fma(specular, rcp_color, diffuse);

				block_light = mix(new_light, block_light, smoothstep(float16_t(LL_DIST - 15), float16_t(LL_DIST), chebyshev_dist));
			} // else block_light = f16vec3(1.0); // DEBUG: `is_lit`

			// DEBUG: Culling & LDS overflow.
			// block_light.gb += f16vec2(sh.index_len < ll.len, sh.index_len == 0);
			// block_light.rgb += distance(max(float16_t(sh.bb_view_min), float16_t(0.0)), max(float16_t(sh.bb_view_max), float16_t(0.0))) * float16_t(0.01);
			// if (sh.index_len > local_index_size) block_light *= 10;

			#ifdef LIGHT_LEVELS
				const float16_t ind_sky = float16_t(0.0);
			#else
				#ifdef NETHER
					const f16vec3 ind_sky = f16vec3(0.3, 0.15, 0.2);
				#elif defined END
					const f16vec3 ind_sky = f16vec3(0.15, 0.075, 0.2);
				#else
					immut float16_t ind_sky = luminance(skylight_color) / float16_t(DIR_SL) * smoothstep(float16_t(0.0), float16_t(1.0), light.y);
				#endif
			#endif

			#if HAND_LIGHT
				#define MAX_HAND_LIGHT_DIST 64 // temp/todo
				if (handLightPackedLR != 0) {
					if (dot(pe, pe) < MAX_HAND_LIGHT_DIST*MAX_HAND_LIGHT_DIST) {
						immut u16vec2 hand_light_lr = unpackUint2x16(uint(handLightPackedLR));

						if (hand_light_lr.x != 0) {
							block_light += get_hand_light(hand_light_lr.x, hand_light.left, f16vec3(-0.2, -0.2, -0.1), view, pe, n_pe, roughness_sss.r, w_tex_normal, w_face_normal, rcp_color, ind_bl, is_hand);
						}

						if (hand_light_lr.y != 0) {
							block_light += get_hand_light(hand_light_lr.y, hand_light.right, f16vec3(0.2, -0.2, -0.1), view, pe, n_pe, roughness_sss.r, w_tex_normal, w_face_normal, rcp_color, ind_bl, is_hand);
						}
					}
				}
			#endif

			f16vec3 final_light = fma(
				fma(
					f16vec3(ind_sky),
					f16vec3(IND_SL),
					f16vec3(AMBIENT * 0.1)
				),
				color_ao.aaa,
				block_light
			);

			#ifndef NETHER
				immut f16vec3 n_w_shadow_light = f16vec3(shadowLightDirectionPlr);
				immut float16_t tex_n_dot_shadow_l = dot(w_tex_normal, n_w_shadow_light);

				if (min(dot(w_face_normal, n_w_shadow_light), tex_n_dot_shadow_l) > float16_t(0.0)) { // TODO: Handle `roughness_sss.g`.
					const float16_t sm_dist = float16_t(shadowDistance * shadowDistanceRenderMul);
					immut f16vec2 specular_diffuse = brdf(tex_n_dot_shadow_l, w_tex_normal, n_pe, n_w_shadow_light, roughness_sss.r);

					f16vec3 sm_light = skylight_color * fma(specular_diffuse.xxx, rcp_color, specular_diffuse.yyy);
					if (chebyshev_dist < sm_dist) {
						vec3 s_screen = vec3(
							unpackUnorm2x16(gbuf.z).y,
							unpackUnorm2x16(gbuf.a)
						);

						sm_light *= mix(
							sample_shadow(s_screen),
							f16vec3(1.0),
							smoothstep(float16_t(sm_dist * (1.0 - SM_FADE_DIST)), sm_dist, chebyshev_dist)
						);
					}

					final_light = fma(sm_light, f16vec3(3.0), final_light);
				}
			#endif

			color = linear(mix(srgb(color_ao.rgb * final_light), srgb(fog_col), vanilla_fog(pe)));
		} else { // Render sky.
			#if defined NETHER || defined END
				color = fog_col;
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

				color = stars + fog_col;

				immut vec3 sun_abs_dist = abs(n_pe - sunDirectionPlr);
				immut bool sun = max3(sun_abs_dist.x, sun_abs_dist.y, sun_abs_dist.z) < 0.04;
				immut bool moon = all(lessThan(abs(n_pe + sunDirectionPlr), fma(skyState.z, 0.0025, 0.02).xxx));

				if (sun || moon) {
					color += skylight_color;
				}
			#endif
		}

		imageStore(colorimg1, texel, vec4(color, 0.0));
	}
}
