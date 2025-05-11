#include "/prelude/core.glsl"

/* Deferred Lighting */

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

readonly
#include "/buf/indirect/control.glsl"

readonly
#include "/buf/index.glsl"

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
	uniform sampler2D colortex3;
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

const uint local_index_size = uint(float(index.data.length()) * LDS_RATIO);

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

		immut i16vec2 texel = i16vec2(uvec2(tile & 65535u, bitfieldExtract(tile, 16, 16)) + gl_LocalInvocationID.xy);
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
	immut uvec2 gbuffer_data = geometry ? texelFetch(colortex2, texel, 0).rg : uvec2(0u);

	immut vec2 texel_size = 1.0 / vec2(view_size());
	immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
	vec3 ndc = fma(vec3(coord, depth), vec3(2.0), vec3(-1.0));

	if (gbuffer_data.y >= 0x80000000u) ndc.z /= MC_HAND_DEPTH; // the most significant bit being 1 indicates hand

	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 pe = mat3(gbufferModelViewInverse) * view;

	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	// check if block light (first 13 bits) isn't zero, and we're within INDEX_DIST
	immut bool lit = (gbuffer_data.y & 8191u) != 0u && chebyshev_dist < float16_t(INDEX_DIST);

	barrier();

	if (lit) {
		immut ivec3 i_pe = ivec3(fma(sign(pe), vec3(0.5), pe));

		atomicMin(sh_bb_pe_min.x, i_pe.x); atomicMax(sh_bb_pe_max.x, i_pe.x);
		atomicMin(sh_bb_pe_min.y, i_pe.y); atomicMax(sh_bb_pe_max.y, i_pe.y);
		atomicMin(sh_bb_pe_min.z, i_pe.z); atomicMax(sh_bb_pe_max.z, i_pe.z);

		immut ivec3 i_view = ivec3(fma(sign(view), vec3(0.5), view));

		atomicMin(sh_bb_view_min.x, i_view.x); atomicMax(sh_bb_view_max.x, i_view.x);
		atomicMin(sh_bb_view_min.y, i_view.y); atomicMax(sh_bb_view_max.y, i_view.y);
		atomicMin(sh_bb_view_min.z, i_view.z); atomicMax(sh_bb_view_max.z, i_view.z);
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
		index_offset += index.offset - cameraPositionFract - gbufferModelViewInverse[3].xyz;

		immut f16vec3 bb_view_min = f16vec3(sh_bb_view_min);
		immut f16vec3 bb_view_max = f16vec3(sh_bb_view_max);

		immut uint16_t global_len = uint16_t(index.len);
		for (uint16_t i = uint16_t(gl_LocalInvocationIndex); i < global_len; i += uint16_t(gl_WorkGroupSize.x * gl_WorkGroupSize.y)) {
			immut uint light_data = index.data[i];

			immut f16vec3 pe_light = f16vec3(
				light_data & 511u,
				bitfieldExtract(light_data, 9, 9),
				bitfieldExtract(light_data, 18, 9)
			) + f16vec3(index_offset);

			immut float16_t intensity = float16_t(bitfieldExtract(light_data.x, 27, 4));

			// distance between light and closest point on bounding box
			// in world-aligned space (player-eye) we can use Manhattan distance
			immut float16_t light_mhtn_dist_from_bb = dot(abs(pe_light - clamp(pe_light, bb_pe_min, bb_pe_max)), f16vec3(1.0));
			immut bool pe_visible = light_mhtn_dist_from_bb <= intensity + float16_t(1.0); // not sure why this +1 is needed here

			immut f16vec3 v_light = f16vec3(pe_light * mat3(gbufferModelViewInverse));
			immut bool view_visible = distance(v_light, clamp(v_light, bb_view_min, bb_view_max)) <= intensity;

			if (pe_visible && view_visible) {
				immut uint j = atomicAdd(sh_index_len, 1u);

				sh_index_data[j] = light_data;
				sh_index_color[j] = index.color[i];
			}
		}
	}

	barrier();

	if (geometry && bitfieldExtract(gbuffer_data.y, 30, 1) == 0u) { // exit on "pure light" flag
		immut f16vec4 color_roughness = f16vec4(imageLoad(colorimg1, texel));

		immut f16vec3 n_pe = f16vec3(normalize(pe));

		immut f16vec4 octa_normal = f16vec4(unpackSnorm4x8(gbuffer_data.x));
		immut f16vec3 w_tex_normal = normalize(octa_decode(octa_normal.xy));
		immut f16vec3 w_face_normal = normalize(octa_decode(octa_normal.zw));

		immut f16vec3 rcp_color = float16_t(1.0) / max(color_roughness.rgb, float16_t(1.0e-4));

		immut f16vec2 light = f16vec2(
			gbuffer_data.y & 8191u,
			bitfieldExtract(gbuffer_data.y, 13, 13)
		) / f16vec2(8191.0);

		#ifdef LIGHT_LEVELS
			f16vec3 block_light = f16vec3(visualize_ll(light.x));
		#else
			f16vec3 block_light = light.x*light.x * f16vec3(1.2, 1.2, 1.0);
		#endif

		if (lit) {
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

				if (mhtn_dist <= intensity) {
					immut uint16_t light_color = sh_index_color[i];

					immut float16_t sq_dist_light = dot(w_rel_light, w_rel_light);
					immut f16vec3 n_w_rel_light = w_rel_light * inversesqrt(sq_dist_light);

					// make falloff start a block away of the light source when the "wide" flag is set
					immut float16_t falloff = float16_t(1.0) / (
						bitfieldExtract(light_data, 31, 1) == 1u ? max(sq_dist_light - float16_t(1.0), float16_t(1.0)) : sq_dist_light
					);

					immut float16_t brightness = min(min(intensity - mhtn_dist, float16_t(1.0)) * intensity * falloff, float16_t(48.0));
					immut uint light_color_u32 = uint(light_color);
					immut f16vec3 illum = brightness * f16vec3(
						bitfieldExtract(light_color_u32, 6, 5),
						light_color & uint16_t(63u),
						bitfieldExtract(light_color_u32, 11, 5)
					);

					immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_rel_light);

					float16_t light_diffuse;

					if (min(tex_n_dot_l, dot(w_face_normal, n_w_rel_light)) > float16_t(0.0)) {
						immut f16vec2 specular_diffuse = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, color_roughness.a);
						specular = fma(specular_diffuse.xxx, illum, specular);
						light_diffuse = specular_diffuse.y;
					} else light_diffuse = float16_t(IND_ILLUM); // very fake GI

					diffuse = fma(light_diffuse.xxx, illum, diffuse);

					/*
						float lighting = IND_ILLUM;

						if (lit) {
							bool visible = true;

							immut vec3 v_pos = (gbufferModelView * vec4(n_pos * -1.5 + pos + pe, 1.0)).xyz;

							for (uint i = 1u; i < 32u && visible; ++i) {
								vec4 clip_sample = gbufferProjection * vec4(view * v_pos / mix(v_pos, view, float(i) / 32.0), 1.0);
								immut vec3 screen_sample = (clip_sample.xyz / clip_sample.w) * 0.5 + 0.5;

								if (screen_sample.z > textureLod(depthtex0, screen_sample.xy, 0).r - 0.001) visible = false;
							}

							lighting += float(visible);
						}
					*/
				}
			}

			/*
				immut uint16_t index_len = uint16_t(sh_index_len);
				for (uint16_t i = uint16_t(0u); i < index_len; i += uint16_t(2u)) {
					immut uint16_t i1 = i + uint16_t(1);
					uvec2 data_aos = uvec2(sh_index_data[i], i1 < index_len ? sh_index_data[i1] : 0u);
					// todo!() do this earlier

					mat3x2 index_pos_soa = mat3x2(
						data_aos & 511u,
						bitfieldExtract(data_aos, 9, 9),
						bitfieldExtract(data_aos, 18, 9)
					);

					mat2x3 index_pos_aos = transpose(index_pos_soa);
					index_pos_aos[0] += offset;
					index_pos_aos[1] += offset;
					index_pos_soa = transpose(index_pos_aos);

					immut f16vec2[3] rel_world_soa = f16vec2[3](
						f16vec2(index_pos_soa[0]),
						f16vec2(index_pos_soa[1]),
						f16vec2(index_pos_soa[2])
					);

					immut f16vec2 intensity_aos = f16vec2(bitfieldExtract(data_aos, 27, 4));
					immut f16vec2 mhtn_dist_aos = abs(rel_world_soa[0]) + abs(rel_world_soa[1]) + abs(rel_world_soa[2]);

					// use this in culling too // todo!() ?
					immut bvec2 in_range = lessThanEqual(mhtn_dist_aos, intensity_aos);
					if (any(in_range)) {
						// todo!() switch to u16vec2 when Iris updates glsl-transformer
						immut i16vec2 light_color_aos = i16vec2(mix(i16vec2(0), i16vec2(sh_index_color[i], i1 < index_len ? sh_index_color[i1] : uint16_t(0u)), in_range));

						immut f16vec2 sq_dist_light_aos = rel_world_soa[0] * rel_world_soa[0] + rel_world_soa[1] * rel_world_soa[1] + rel_world_soa[2] * rel_world_soa[2];
						immut f16vec2 rcp_dist_light_aos = inversesqrt(sq_dist_light_aos);
						immut f16vec2[3] n_rel_world_soa = f16vec2[3](
							f16vec2(rel_world_soa[0] * rcp_dist_light_aos),
							f16vec2(rel_world_soa[1] * rcp_dist_light_aos),
							f16vec2(rel_world_soa[2] * rcp_dist_light_aos)
						);

						// make falloff start a block away of the light source when the "wide" flag is set
						immut f16vec2 falloff_aos = float16_t(1.0) / (
							mix(sq_dist_light_aos, max(sq_dist_light_aos - float16_t(1.0), float16_t(1.0)), bitfieldExtract(data_aos, 31, 1) == uvec2(1u))
						);

						immut f16vec2 brightness_aos = min(min(intensity_aos - mhtn_dist_aos, float16_t(1.0)) * intensity_aos * falloff_aos, float16_t(48.0));
						immut uvec2 light_color_u32_aos = uvec2(light_color_aos);

						immut f16vec2[3] illum_soa = f16vec2[3](
							brightness_aos * f16vec2(bitfieldExtract(light_color_u32_aos, 6, 5)),
							brightness_aos * f16vec2(light_color_aos & int16_t(63)),
							brightness_aos * f16vec2(bitfieldExtract(light_color_u32_aos, 11, 5))
						);

						immut f16vec2 tex_n_dot_l_aos = w_tex_normal.x * n_rel_world_soa[0] + w_tex_normal.y * n_rel_world_soa[1] + w_tex_normal.z * n_rel_world_soa[2];
						immut f16vec2 face_n_dot_l_aos = w_face_normal.x * n_rel_world_soa[0] + w_face_normal.y * n_rel_world_soa[1] + w_face_normal.z * n_rel_world_soa[2];

						f16vec2 diffuse_aos;

						immut f16vec2 min_n_dot_l_aos = min(tex_n_dot_l_aos, face_n_dot_l_aos);

						if (max(min_n_dot_l_aos.x, min_n_dot_l_aos.y) > float16_t(0.0)) {
							immut f16vec2[2] specular_diffuse_aos = f16vec2[2](
								brdf(tex_n_dot_l_aos.x, w_tex_normal, n_pe, f16vec3(n_rel_world_soa[0].x, n_rel_world_soa[1].x, n_rel_world_soa[2].x), color_roughness.a),
								brdf(tex_n_dot_l_aos.y, w_tex_normal, n_pe, f16vec3(n_rel_world_soa[0].y, n_rel_world_soa[1].y, n_rel_world_soa[2].y), color_roughness.a)
							);
							immut f16vec2[2] specular_diffuse_soa = f16vec2[2](
								f16vec2(specular_diffuse_aos[0].x, specular_diffuse_aos[1].x),
								f16vec2(specular_diffuse_aos[0].y, specular_diffuse_aos[1].y)
							);

							immut f16vec2[3] colored_specular_soa = f16vec2[3](
								specular_diffuse_soa[0] * illum_soa[0],
								specular_diffuse_soa[0] * illum_soa[1],
								specular_diffuse_soa[0] * illum_soa[2]
							);

							immut f16vec3[2] colored_specular_aos = f16vec3[2](
								f16vec3(colored_specular_soa[0].x, colored_specular_soa[1].x, colored_specular_soa[2].x),
								f16vec3(colored_specular_soa[0].y, colored_specular_soa[1].y, colored_specular_soa[2].y)
							);

							specular += colored_specular_aos[0] + colored_specular_aos[1];
							diffuse_aos = specular_diffuse_soa[1];
						} else diffuse_aos = f16vec2(IND_ILLUM); // very fake GI

						immut f16vec2[3] colored_diffuse_soa = f16vec2[3](
							diffuse_aos * illum_soa[0],
							diffuse_aos * illum_soa[1],
							diffuse_aos * illum_soa[2]
						);

						immut f16vec3[2] colored_diffuse_aos = f16vec3[2](
							f16vec3(colored_diffuse_soa[0].x, colored_diffuse_soa[1].x, colored_diffuse_soa[2].x),
							f16vec3(colored_diffuse_soa[0].y, colored_diffuse_soa[1].y, colored_diffuse_soa[2].y)
						);

						diffuse += colored_diffuse_aos[0] + colored_diffuse_aos[1];
					}
				}
			*/

			// Undo the multiplication from packing light color and brightness
			const vec3 packing_scale = 15.0 * vec3(31.0, 63.0, 31.0);
			immut f16vec3 new_light = f16vec3(float(INDEXED_BLOCK_LIGHT * 3) / packing_scale) * light.x * fma(specular, rcp_color, diffuse);

			block_light = mix(new_light, block_light, smoothstep(float16_t(INDEX_DIST - 15), float16_t(INDEX_DIST), chebyshev_dist));
		} // else block_light = f16vec3(1.0); // DEBUG `lit`

		// Debug culling & LDS overflow
		// block_light.gb += f16vec2(sh_index_len < index.len, sh_index_len == 0);
		// block_light.rgb += distance(max(float16_t(sh_bb_view_min), float16_t(0.0)), max(float16_t(sh_bb_view_max), float16_t(0.0))) * float16_t(0.01);
		// if (sh_index_len > local_index_size) block_light *= 10;

		#ifdef LIGHT_LEVELS
			const float16_t sky_light = float16_t(0.0);
		#else
			#ifdef NETHER
				const f16vec3 sky_light = f16vec3(0.3, 0.15, 0.2);
			#elif defined END
				const f16vec3 sky_light = f16vec3(0.15, 0.075, 0.2);
			#else
				immut float16_t sky_light = float16_t(1.0) - sqrt(float16_t(1.0) - light.y);
			#endif
		#endif

		#if HAND_LIGHT
			if (gbuffer_data.y < 0x80000000u) { // not hand
				immut uint hand_light_count = hand_light.data.a;

				if (hand_light_count > 0u) {
					immut uvec3 hand_light_color = hand_light.data.rgb;

					immut f16vec3 illum = float16_t(float(HAND_LIGHT) / 255.0) / (float16_t(hand_light_count) * float16_t(dot(pe, pe))) * f16vec3(hand_light_color.rgb);

					immut f16vec2 specular_diffuse = brdf(float16_t(1.0), w_tex_normal, n_pe, n_pe * float16_t(-0.999), color_roughness.a);
					block_light = fma(fma(specular_diffuse.xxx, rcp_color, specular_diffuse.yyy), illum, block_light);
				}
			}
		#endif

		immut float16_t emission = float16_t(bitfieldExtract(gbuffer_data.y, 26, 4));
		immut float16_t emi = fma(emission, float16_t(0.2), luminance(color_roughness.rgb));
		f16vec3 final_light = sky_light * float16_t(0.375) + emi*emi*emi*emi * float16_t(0.005) + block_light;

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

			if (min(dot(w_face_normal, n_w_shadow_light), tex_n_dot_shadow_l) > float16_t(0.0)) {
				const float16_t sm_dist = float16_t(shadowDistance * shadowDistanceRenderMul);
				immut f16vec2 specular_diffuse = brdf(tex_n_dot_shadow_l, w_tex_normal, n_pe, n_w_shadow_light, color_roughness.a);

				f16vec3 light = skylight() * fma(specular_diffuse.xxx, rcp_color, specular_diffuse.yyy);
				if (chebyshev_dist < sm_dist) {
					immut f16vec3 sm_light = sample_shadow(texelFetch(colortex3, texel, 0).rgb);

					light *= mix(sm_light, f16vec3(1.0), smoothstep(float16_t(sm_dist * (1.0 - SHADOW_FADE_DIST)), sm_dist, chebyshev_dist));
				}

				final_light = fma(light, f16vec3(3.0), final_light);
			}
		#endif

		imageStore(colorimg1, texel, vec4(mix(color_roughness.rgb * final_light, fog_col, edge_fog(pe)), 0.0));
	}
}
