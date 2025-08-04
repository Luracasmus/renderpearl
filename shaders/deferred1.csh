#include "/prelude/core.glsl"

/* Deferred Lighting */

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

readonly
#include "/buf/indirect/control.glsl"

readonly
#include "/buf/ll.glsl"

#if HAND_LIGHT
	readonly
	#include "/buf/hand_light.glsl"
#endif

uniform vec3 cameraPositionFract;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
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

#ifdef LIGHT_LEVELS
	#include "/lib/llv.glsl"
#endif

const uint local_index_size = uint(float(LL_CAPACITY) * LDS_RATIO);

shared ivec3 sh_bb_pe_min;
shared ivec3 sh_bb_pe_max;
shared ivec3 sh_bb_view_min;
shared uint sh_index_len;
shared ivec3 sh_bb_view_max;
shared uint[local_index_size] sh_index_data;
shared uint16_t[local_index_size] sh_index_color;

void main() {
	#ifdef INT16
		immut i16vec2 texel = i16vec2(indirect_control.coords[gl_WorkGroupID.x]) + i16vec2(gl_LocalInvocationID.xy);
	#else
		immut uint tile = indirect_control.coords[gl_WorkGroupID.x];

		immut i16vec2 texel = i16vec2(uvec2(tile & 65535u, tile >> 16u) + gl_LocalInvocationID.xy);
	#endif

	if (gl_LocalInvocationIndex == 0u) {
		sh_index_len = 0u;

		const ivec3 i32_max = ivec3(0x7fffffff);
		const ivec3 i32_min = ivec3(0x80000000);

		sh_bb_pe_min = i32_max;
		sh_bb_pe_max = i32_min;
		sh_bb_view_min = i32_max;
		sh_bb_view_max = i32_min;
	}

	immut float depth = texelFetch(depthtex0, texel, 0).r;
	immut bool geometry = depth < 1.0;
	immut uvec4 gbuf = geometry ? texelFetch(colortex2, texel, 0) : uvec4(0u);

	immut vec2 texel_size = 1.0 / vec2(view_size());
	immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
	vec3 ndc = fma(vec3(coord, depth), vec3(2.0), vec3(-1.0));

	if (gbuf.y >= 0x80000000u) ndc.z /= MC_HAND_DEPTH; // the most significant bit being 1 indicates hand

	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 pe = mat3(gbufferModelViewInverse) * view;

	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	// check if block light (first 13 bits) isn't zero, and we're within LL_DIST
	immut bool lit = (gbuf.y & 32767u) != 0u && chebyshev_dist < float16_t(LL_DIST);

	barrier();

	if (lit) {
		immut ivec3 ceil_pe = ivec3(pe + 0.5);
		immut ivec3 floor_pe = ivec3(pe - 0.5);

		atomicMin(sh_bb_pe_min.x, floor_pe.x); atomicMax(sh_bb_pe_max.x, ceil_pe.x);
		atomicMin(sh_bb_pe_min.y, floor_pe.y); atomicMax(sh_bb_pe_max.y, ceil_pe.y);
		atomicMin(sh_bb_pe_min.z, floor_pe.z); atomicMax(sh_bb_pe_max.z, ceil_pe.z);

		immut ivec3 ceil_view = ivec3(view + 0.5);
		immut ivec3 floor_view = ivec3(view - 0.5);

		atomicMin(sh_bb_view_min.x, floor_view.x); atomicMax(sh_bb_view_max.x, ceil_view.x);
		atomicMin(sh_bb_view_min.y, floor_view.y); atomicMax(sh_bb_view_max.y, ceil_view.y);
		atomicMin(sh_bb_view_min.z, floor_view.z); atomicMax(sh_bb_view_max.z, ceil_view.z);
	}

	/*
		if (subgroupAny(lit)) {
			immut vec3 sg_pe_min = subgroupMin(lit ? pe : vec3(1.0/0.0));
			immut vec3 sg_pe_max = subgroupMax(lit ? pe : vec3(-1.0/0.0));

			immut vec3 sg_view_min = subgroupMin(lit ? view : vec3(1.0/0.0));
			immut vec3 sg_view_max = subgroupMax(lit ? view : vec3(-1.0/0.0));

			if (subgroupElect()) {
				immut ivec3 i_sg_pe_min = ivec3(fma(sign(sg_pe_min), vec3(0.5), sg_pe_min));
				immut ivec3 i_sg_bb_max = ivec3(fma(sign(sg_pe_max), vec3(0.5), sg_pe_max));

				atomicMin(sh_bb_pe_min.x, i_sg_pe_min.x); atomicMax(sh_bb_pe_max.x, i_sg_bb_max.x);
				atomicMin(sh_bb_pe_min.y, i_sg_pe_min.y); atomicMax(sh_bb_pe_max.y, i_sg_bb_max.y);
				atomicMin(sh_bb_pe_min.z, i_sg_pe_min.z); atomicMax(sh_bb_pe_max.z, i_sg_bb_max.z);

				immut ivec3 i_sg_view_min = ivec3(fma(sign(sg_view_min), vec3(0.5), sg_view_min));
				immut ivec3 i_sg_view_max = ivec3(fma(sign(sg_view_max), vec3(0.5), sg_view_max));

				atomicMin(sh_bb_view_min.x, i_sg_view_min.x); atomicMax(sh_bb_view_max.x, i_sg_view_max.x);
				atomicMin(sh_bb_view_min.y, i_sg_view_min.y); atomicMax(sh_bb_view_max.y, i_sg_view_max.y);
				atomicMin(sh_bb_view_min.z, i_sg_view_min.z); atomicMax(sh_bb_view_max.z, i_sg_view_max.z);
			}
		}
	*/

	barrier();

	immut f16vec3 bb_pe_min = f16vec3(sh_bb_pe_min);
	immut f16vec3 bb_pe_max = f16vec3(sh_bb_pe_max);

	vec3 index_offset = vec3(-255.5);

	if (all(greaterThanEqual(bb_pe_max, bb_pe_min))) { // make sure this tile isn't fully unlit, out of range or sky
		index_offset += ll.offset - cameraPositionFract - gbufferModelViewInverse[3].xyz;

		immut f16vec3 bb_view_min = f16vec3(sh_bb_view_min);
		immut f16vec3 bb_view_max = f16vec3(sh_bb_view_max);

		immut uint16_t global_len = uint16_t(ll.len);
		for (uint16_t i = uint16_t(gl_LocalInvocationIndex); i < global_len; i += uint16_t(gl_WorkGroupSize.x * gl_WorkGroupSize.y)) {
			immut uint light_data = ll.data[i];

			immut f16vec3 pe_light = f16vec3(
				light_data & 511u,
				bitfieldExtract(light_data, 9, 9),
				bitfieldExtract(light_data, 18, 9)
			) + f16vec3(index_offset);

			// add 0.5 to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting
			immut float16_t offset_intensity = float16_t(bitfieldExtract(light_data.x, 27, 4)) + float16_t(0.5);

			// distance between light and closest point on bounding box
			// in world-aligned space (player-eye) we can use Manhattan distance
			immut float16_t light_mhtn_dist_from_bb = dot(abs(pe_light - clamp(pe_light, bb_pe_min, bb_pe_max)), f16vec3(1.0));
			immut bool pe_visible = light_mhtn_dist_from_bb <= offset_intensity; // not sure why this +1 is needed here

			immut f16vec3 v_light = f16vec3(pe_light * mat3(gbufferModelViewInverse));
			immut bool view_visible = distance(v_light, clamp(v_light, bb_view_min, bb_view_max)) <= offset_intensity;

			if (pe_visible && view_visible) {
				immut uint j = atomicAdd(sh_index_len, 1u);

				sh_index_data[j] = light_data;
				sh_index_color[j] = ll.color[i];
			}
		}
	}

	barrier();

	if (geometry && bitfieldExtract(gbuf.y, 30, 1) == 0u) { // exit on "pure light" flag
		immut f16vec4 color_ao = f16vec4(imageLoad(colorimg1, texel));
		immut f16vec3 skylight_color = skylight();

		immut f16vec3 n_pe = f16vec3(normalize(pe));

		immut f16vec2 roughness_sss = f16vec2(unpackUnorm4x8(gbuf.z).xy);

		immut f16vec4 octa_normal = f16vec4(unpackSnorm4x8(gbuf.x));
		immut f16vec3 w_tex_normal = normalize(octa_decode(octa_normal.xy));
		immut f16vec3 w_face_normal = normalize(octa_decode(octa_normal.zw));

		immut f16vec3 rcp_color = float16_t(1.0) / max(color_ao.rgb, float16_t(1.0e-4));

		immut f16vec2 light = f16vec2(vec2(
			gbuf.y & 32767u,
			bitfieldExtract(gbuf.y, 15, 15)
		) / 32767.0);

		#ifdef LIGHT_LEVELS
			f16vec3 block_light = f16vec3(visualize_ll(light.x));
		#else
			f16vec3 block_light = light.x * f16vec3(BL_FALLBACK_R, BL_FALLBACK_G, BL_FALLBACK_B);
		#endif

		if (lit) {
			immut float16_t ind_bl = float16_t(IND_BL) * color_ao.a;

			immut vec3 offset = vec3(index_offset) - pe;

			f16vec3 diffuse = f16vec3(0.0);
			f16vec3 specular = f16vec3(0.0);

			immut uint16_t index_len = uint16_t(sh_index_len);
			for (uint16_t i = uint16_t(0u); i < index_len; ++i) {
				immut uint light_data = sh_index_data[i];

				immut f16vec3 w_rel_light = f16vec3(vec3(
					light_data & 511u,
					bitfieldExtract(light_data, 9, 9),
					bitfieldExtract(light_data, 18, 9)
				) + offset);

				immut float16_t intensity = float16_t(bitfieldExtract(light_data.x, 27, 4));
				immut float16_t mhtn_dist = dot(abs(w_rel_light), f16vec3(1.0));

				if (mhtn_dist < intensity + float16_t(0.5)) {
					immut uint16_t light_color = sh_index_color[i];

					immut float16_t sq_dist_light = dot(w_rel_light, w_rel_light);
					immut f16vec3 n_w_rel_light = w_rel_light * inversesqrt(sq_dist_light);

					// make falloff start a block away of the light source when the "wide" flag (most significant bit) is set
					immut float16_t falloff = float16_t(1.0) / (
						light_data >= 0x80000000u ? max(sq_dist_light - float16_t(1.0), float16_t(1.0)) : sq_dist_light
					);

					immut float16_t light_level = intensity - mhtn_dist + float16_t(0.5);
					float16_t brightness = intensity * falloff;
					brightness *= smoothstep(float16_t(0.0), float16_t(LL_FALLOFF_MARGIN), light_level);
					brightness /= min(light_level, float16_t(15.0)) * float16_t(1.0/15.0); // compensate for multiplication with light.x later on, in order to make the falloff follow the inverse square law as much as possible
					brightness = min(brightness, float16_t(48.0)); // prevent float16_t overflow later on

					immut f16vec3 illum = brightness * f16vec3(
						(light_color >> uint16_t(6u)) & uint16_t(31u),
						light_color & uint16_t(63u),
						(light_color >> uint16_t(11u))
					);

					immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_rel_light);

					float16_t light_diffuse = ind_bl; // very fake GI

					if (min(tex_n_dot_l, dot(w_face_normal, n_w_rel_light)) > float16_t(0.0)) {
						immut f16vec2 specular_diffuse = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, roughness_sss.r);
						specular = fma(specular_diffuse.xxx, illum, specular);
						light_diffuse += specular_diffuse.y;
					}

					diffuse = fma(light_diffuse.xxx, illum, diffuse);
				}
			}

			// Undo the multiplication from packing light color and brightness
			const vec3 packing_scale = vec3(15u * uvec3(31u, 63u, 31u));
			immut f16vec3 new_light = f16vec3(float(DIR_BL * 3) / packing_scale) * light.x * fma(specular, rcp_color, diffuse);

			block_light = mix(new_light, block_light, smoothstep(float16_t(LL_DIST - 15), float16_t(LL_DIST), chebyshev_dist));
		} // else block_light = f16vec3(1.0); // DEBUG `lit`

		// Debug culling & LDS overflow
		// block_light.gb += f16vec2(sh_index_len < ll.len, sh_index_len == 0);
		// block_light.rgb += distance(max(float16_t(sh_bb_view_min), float16_t(0.0)), max(float16_t(sh_bb_view_max), float16_t(0.0))) * float16_t(0.01);
		// if (sh_index_len > local_index_size) block_light *= 10;

		#ifdef LIGHT_LEVELS
			const float16_t ind_sky = float16_t(0.0);
		#else
			#ifdef NETHER
				const f16vec3 ind_sky = f16vec3(0.3, 0.15, 0.2);
			#elif defined END
				const f16vec3 ind_sky = f16vec3(0.15, 0.075, 0.2);
			#else
				// immut float16_t ind_sky = (float16_t(1.0) - sqrt(float16_t(1.0) - light.y)) * luminance(skylight_color) / float16_t(DIR_SL);
				// immut float16_t negative_x = light.y - float16_t(1.0);
				// float16_t falloff = saturate(float16_t(1.0/225.0) / (negative_x*negative_x));
				// falloff *= smoothstep(float16_t(0.0), float16_t(float(LL_FALLOFF_MARGIN) / 15.0), light.y);
				// immut float16_t ind_sky = falloff * luminance(skylight_color) / float16_t(DIR_SL);

				immut float16_t ind_sky = luminance(skylight_color) / float16_t(DIR_SL) * smoothstep(float16_t(0.0), float16_t(1.0), light.y);
			#endif
		#endif

		#if HAND_LIGHT
			if (gbuf.y < 0x80000000u) { // not hand
				immut uint hand_light_count = hand_light.data.a;

				if (hand_light_count != 0u) {
					immut uvec3 hand_light_color = hand_light.data.rgb;

					immut f16vec3 illum = float16_t(float(HAND_LIGHT) / 255.0) / (float16_t(hand_light_count) * float16_t(dot(pe, pe))) * f16vec3(hand_light_color.rgb);

					immut f16vec2 specular_diffuse = brdf(float16_t(1.0), w_tex_normal, n_pe, n_pe * float16_t(-0.999), roughness_sss.r);
					block_light = fma(fma(specular_diffuse.xxx, rcp_color, specular_diffuse.yyy), illum, block_light);
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

		#ifdef NETHER
			immut f16vec3 fog_col = linear(f16vec3(fogColor));
		#else
			#ifdef END
				immut f16vec3 fog_col = sky(n_pe);
			#else
				immut float16_t sky_fog_val = sky_fog(float16_t(n_pe.y));
				immut f16vec3 fog_col = sky(sky_fog(float16_t(n_pe.y)), n_pe, sunDirectionPlr);
			#endif

			immut f16vec3 n_w_shadow_light = f16vec3(shadowLightDirectionPlr);
			immut float16_t tex_n_dot_shadow_l = dot(w_tex_normal, n_w_shadow_light);

			if (min(dot(w_face_normal, n_w_shadow_light), tex_n_dot_shadow_l) > float16_t(0.0)) { // todo!() handle roughness_sss.g
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

		imageStore(colorimg1, texel, vec4(mix(color_ao.rgb * final_light, fog_col, edge_fog(pe)), 0.0));
	}
}
