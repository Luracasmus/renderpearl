#include "/prelude/core.glsl"

/* RENDERTARGETS: 1 */

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
	uniform vec3 shadowLightDirectionPlr;

	#include "/lib/skylight.glsl"
	#include "/lib/sm/distort.glsl"
	#include "/lib/sm/shadows.glsl"
#endif

#ifdef END
	uniform float frameTimeCounter;
	#include "/lib/prng/fast_rand.glsl"
#endif

#include "/lib/view_size.glsl"
#include "/lib/mmul.glsl"
#include "/lib/luminance.glsl"
#include "/lib/srgb.glsl"
#define SKY_FSH
#include "/lib/fog.glsl"
#include "/lib/material/specular.glsl"

readonly
#include "/buf/ll.glsl"
uniform vec3 cameraPositionFract;
#include "/lib/brdf.glsl"

#ifndef NO_NORMAL
	#include "/lib/material/normal.glsl"
#endif

#ifndef NETHER
	uniform float frameTimeCounter;

	#include "/lib/prng/pcg.glsl"

	#ifdef END
		#include "/lib/prng/fast_rand.glsl"
	#else
		uniform vec3 sunDirectionPlr;
	#endif
#endif

void add_ll_light(
	inout f16vec3 specular, inout f16vec3 diffuse,
	f16vec3 w_face_normal, f16vec3 w_tex_normal,
	f16vec3 n_pe, float16_t roughness, float16_t ind_bl,
	vec3 ll_and_pe_offset, uint i
) {
	immut uint light_data = ll.data[i];

	immut f16vec3 w_rel_light = f16vec3(vec3(
		light_data & 511u,
		bitfieldExtract(light_data, 9, 9),
		bitfieldExtract(light_data, 18, 9)
	) + ll_and_pe_offset);

	immut float16_t intensity = float16_t(bitfieldExtract(light_data.x, 27, 4));
	immut float16_t mhtn_dist = dot(abs(w_rel_light), f16vec3(1.0));

	if (mhtn_dist < intensity + float16_t(0.5)) {
		immut uint16_t light_color = ll.color[i];

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
			immut f16vec2 specular_diffuse = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, roughness);
			specular = fma(specular_diffuse.xxx, illum, specular);
			light_diffuse += specular_diffuse.y;
		}

		diffuse = fma(light_diffuse.xxx, illum, diffuse);
	}
}

void main() {
	#if defined TRANSLUCENT || defined ALPHA_CHECK
		f16vec4 color = f16vec4(texture(gtexture, v.coord));
	#else
		f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);
	#endif

	#if defined ALPHA_CHECK && SUBGROUP_ENABLED
		immut bool will_discard = color.a < float16_t(alphaTestRef));
		if (subgroupAll(will_discard) { discard; }
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

	#ifdef TRANSLUCENT
		immut uint16_t packed_alpha = uint16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 5, 11));
		color.a *= float16_t(1.0/2047.0) * float16_t(packed_alpha);
	#endif

	#if defined SM && defined MC_SPECULAR_MAP
		immut float16_t roughness = map_roughness(float16_t(texture(specular, v.coord).SM_CH));
	#else
		immut float16_t avg_luma = unpackFloat2x16(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma).y;

		immut float16_t roughness = gen_roughness(luminance(color.rgb), avg_luma);
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
			immut float16_t handedness = fma(float16_t(bitfieldExtract(v.uint4_bool1_unorm11_float16_emission_handedness_alpha_luma, 4, 1)), float16_t(2.0), float16_t(-1.0));

			immut mat3 w_tbn = mat3(w_face_tangent, vec3(cross(w_face_tangent, w_face_normal) * handedness), w_face_normal);

			#if NORMALS == 1 && defined MC_NORMAL_MAP
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * sample_normal(texture(normals, v.coord).rg));
			#else
				immut f16vec3 w_tex_normal = f16vec3(w_tbn * gen_normal(gtexture, tint, v.coord, v.unorm2x16_mid_coord, v.uint2x16_face_tex_size, luminance(color.rgb)));
			#endif
		#endif
	#endif

	color.rgb = linear(color.rgb);
	immut f16vec3 rcp_color = float16_t(1.0) / max(color.rgb, float16_t(1.0e-5));

	immut vec3 ndc = fma(vec3(gl_FragCoord.xy / vec2(view_size()), gl_FragCoord.z), vec3(2.0), vec3(-1.0));
	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 pe = MV_INV * view;
	immut f16vec3 n_pe = f16vec3(normalize(pe));
	immut f16vec3 abs_pe = abs(f16vec3(pe));
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	f16vec3 light = f16vec3(0.0);

	#ifndef NETHER
		immut f16vec3 sky_light_color = skylight();
		immut f16vec3 n_w_shadow_light = f16vec3(shadowLightDirectionPlr);

		#ifdef NO_NORMAL
			const float16_t face_n_dot_l = float16_t(1.0);
			const float16_t tex_n_dot_l = float16_t(1.0);
		#else
			immut float16_t face_n_dot_l = dot(w_face_normal, n_w_shadow_light);
			immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_shadow_light);
		#endif

		/*#if SSS
			f16vec3 dir_sky_light = sample_shadow(v.s_screen);
		#endif*/

		if (min(face_n_dot_l, tex_n_dot_l) > float16_t(0.0)) {
			const float16_t sm_dist = float16_t(shadowDistance * shadowDistanceRenderMul);
			immut f16vec2 specular_diffuse = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_shadow_light, roughness);

			f16vec3 dir_sky_light = sky_light_color * fma(specular_diffuse.xxx, rcp_color, specular_diffuse.yyy);

			if (chebyshev_dist < sm_dist) {
				dir_sky_light *= mix(
					sample_shadow(v.s_screen),
					f16vec3(1.0),
					smoothstep(float16_t(sm_dist * (1.0 - SM_FADE_DIST)), sm_dist, chebyshev_dist)
				);
			}

			light += float16_t(3.0) * dir_sky_light;
		}

		/*#if SSS
			else light = fma(dir_sky_light, sky_light_color, light);  // TODO: We should use AO here.
		#endif*/
	#endif

	immut f16vec2 block_sky_light =
		#ifdef TERRAIN
			f16vec2(v.light);
		#else
			unpackFloat2x16(v.float2x16_light);
		#endif

	#ifdef LIGHT_LEVELS
		const float16_t ind_sky = float16_t(0.0);
	#else
		#ifdef NETHER
			const f16vec3 ind_sky = f16vec3(0.3, 0.15, 0.2);
		#elif defined END
			const f16vec3 ind_sky = f16vec3(0.15, 0.075, 0.2);
		#else
			immut float16_t ind_sky = luminance(sky_light_color) / float16_t(DIR_SL) * smoothstep(float16_t(0.0), float16_t(1.0), block_sky_light.y);
		#endif
	#endif

	#ifdef TERRAIN
		immut float16_t ao = float16_t(v.ao);
	#else
		const float16_t ao = float16_t(0.9);
	#endif

	light += ao * fma(f16vec3(ind_sky), f16vec3(IND_SL), f16vec3(AMBIENT * 0.1));

	// Light list stuff.
	immut bool is_block_lit = (block_sky_light.x != float16_t(0.0) && !will_discard && !gl_HelperInvocation);
	if (subgroupAny(is_block_lit)) {
		#ifdef LIGHT_LEVELS
			f16vec3 block_light = f16vec3(visualize_ll(block_sky_light.x));
		#else
			f16vec3 block_light = block_sky_light.x * f16vec3(BL_FALLBACK_R, BL_FALLBACK_G, BL_FALLBACK_B);
		#endif

		vec3 lit_max_pe, lit_max_view, lit_min_pe, lit_min_view;
		if (is_block_lit) {
			lit_max_pe = pe;
			lit_max_view = view;

			lit_min_pe = pe;
			lit_min_view = view;
		} else { // We don't want unlit or helper invocations making the bounding boxes bigger but we still need them to be active.
			const float minus_inf = uintBitsToFloat(0xFF800000u);
			lit_max_pe = minus_inf.xxx;
			lit_max_view = minus_inf.xxx;

			const float inf = uintBitsToFloat(0x7F800000u);
			lit_min_pe = inf.xxx;
			lit_min_view = inf.xxx;
		}

		immut vec3 sg_pe_min = subgroupMin(lit_min_pe);
		immut vec3 sg_pe_max = subgroupMax(lit_max_pe);

		immut vec3 sg_view_min = subgroupMin(lit_min_view);
		immut vec3 sg_view_max = subgroupMax(lit_max_view);

		immut vec3 ll_offset = vec3(-255.5) + subgroupBroadcastFirst(ll.offset) - cameraPositionFract - mvInv3;
		immut uint16_t sg_inv_id = uint16_t(gl_SubgroupInvocationID);
		immut uint16_t global_len = uint16_t(subgroupBroadcastFirst(ll.len));
		const uint16_t sg_size = uint16_t(gl_SubgroupSize);

		immut vec3 ll_and_pe_offset = ll_offset - pe;
		immut float16_t ind_bl = float16_t(IND_BL) * ao;
		f16vec3 diffuse = f16vec3(0.0);
		f16vec3 specular = f16vec3(0.0);


		for (uint16_t sg_i = uint16_t(0u); sg_i < global_len; sg_i += sg_size) {
			bool is_in_bb;

			// Check if light is inside the subgroup bounding boxes.
			immut uint16_t collab_inv_i = sg_i + sg_inv_id;

			if (collab_inv_i < global_len) {
				immut uint light_data = ll.data[collab_inv_i];

				immut f16vec3 pe_light = f16vec3(
					light_data & 511u,
					bitfieldExtract(light_data, 9, 9),
					bitfieldExtract(light_data, 18, 9)
				) + f16vec3(ll_offset);

				// Add '0.5' to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
				immut float16_t offset_intensity = float16_t(bitfieldExtract(light_data.x, 27, 4)) + float16_t(0.5);

				// Distance between light and closest point on bounding box.
				// In world-aligned space (player-eye) we can use Manhattan distance.
				immut float16_t light_mhtn_dist_from_bb = dot(abs(pe_light - clamp(pe_light, sg_pe_min, sg_pe_max)), f16vec3(1.0));
				immut bool pe_visible = light_mhtn_dist_from_bb <= offset_intensity; // not sure why this +1 is needed here

				immut f16vec3 v_light = f16vec3(pe_light * MV_INV);
				immut bool view_visible = distance(v_light, clamp(v_light, sg_view_min, sg_view_max)) <= offset_intensity;

				is_in_bb = pe_visible && view_visible;
			} else {
				is_in_bb = false;
			}

			if (subgroupAny(is_in_bb)) {
				immut uvec4 ballot = subgroupBallot(is_in_bb);
				immut uint16_t lsb = uint16_t(subgroupBallotFindLSB(ballot));
				immut uint16_t msb = uint16_t(subgroupBallotFindMSB(ballot));

				// Now we actually check the lights per invocation, skipping the ones which are outside the BBs.

				//add_ll_light(specular, diffuse, w_face_normal, w_tex_normal, n_pe, roughness, ind_bl, offset, i + lsb);

				if (is_block_lit) {
					for (uint16_t i = lsb; i <= msb; ++i) {
						if (subgroupBallotBitExtract(ballot, i)) { // This is always true when `i == lsb` or `i == msb`.
							add_ll_light(specular, diffuse, w_face_normal, w_tex_normal, n_pe, roughness, ind_bl, ll_and_pe_offset, i + sg_i);
						}
					}
				}

				//add_ll_light(specular, diffuse, w_face_normal, w_tex_normal, n_pe, roughness, ind_bl, offset, i + msb);
			}
		}

		/*for (uint16_t i = uint16_t(0u); i < global_len; ++i) {
			add_ll_light(specular, diffuse, w_face_normal, w_tex_normal, n_pe, roughness, ind_bl, ll_and_pe_offset, i);
		}*/

		// Undo the multiplication from packing light color and brightness.
		const vec3 packing_scale = vec3(15u * uvec3(31u, 63u, 31u));
		immut f16vec3 ll_block_light = f16vec3(float(DIR_BL * 3) / packing_scale) * block_sky_light.x * fma(specular, rcp_color, diffuse);

		block_light = mix(ll_block_light, block_light, smoothstep(float16_t(LL_DIST - 15), float16_t(LL_DIST), chebyshev_dist));

		light += block_light;
	}

	#ifdef ALPHA_CHECK
		if (will_discard) { discard; } // TODO: We may want to move more stuff after this that doesn't require derivatives or SG stuff.
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
			immut f16vec3 srgb_fog_col = srgb(f16vec3(fogColor));
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
