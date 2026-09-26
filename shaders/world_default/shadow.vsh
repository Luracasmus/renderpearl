#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };

#ifdef SM_ENTITY
#endif
#ifdef SM_PLR
#endif
#ifdef SM_BLOCK_ENTITY
#endif

#ifdef CLRWL
	#define TEXTURED
#endif

#include "/lib/mmul.glsl"

#ifdef TERRAIN
	uniform bool LLCollect;
	uniform vec3 cameraPosition, cameraPositionFract;
	uniform mat4 gbufferProjection, gbufferProjectionInverse, shadowModelViewInverse;
	uniform sampler2D gtexture;

	in vec2 mc_Entity;
	in vec2 mc_midTexCoord;
	in vec4 at_midBlock;

	#include "/lib/mv_inv.glsl"
	#include "/lib/srgb.glsl"
	#include "/lib/push_to_llq.glsl"
#endif

#ifdef SM_ACTIVE
	#include "/lib/sm/distort.glsl"

	#ifdef TEXTURED
		out VertexData { layout(location = 0) noperspective vec2 coord; } v;
	#endif
#endif

vec3 get_view() {
	return rot_trans_mmul(mat4(gl_ModelViewMatrix), vec3(gl_Vertex));
}

void main() {
	#ifdef SM_ACTIVE
		immut vec3 view = get_view();
		immut vec3 clip = shadow_proj_scale.xxy * view;
		gl_Position = vec4(clip.xy * distortion(clip.xy), clip.z, 1.0);
		// RDNA4 ISA documentation states `.w` is optional, but the fallback value doesn't seem to be `1.0` on AMD drivers, so we write to it anyways.

		#ifdef TEXTURED
			v.coord = rot_trans_mmul(mat4(gl_TextureMatrix[0]), vec2(gl_MultiTexCoord0));
		#endif
	#else
		gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
	#endif

	#ifdef TERRAIN
		if (LLCollect) {
			// Run only once per face.
			if ((gl_VertexID & 3) == 1) {
				immut float16_t intensity = max(float16_t(mc_Entity.x), float16_t(at_midBlock.w));

				// Cull too weak or non-lights.
				if (intensity >= float16_t(MIN_LL_INTENSITY)) {
					#ifndef SM_ACTIVE
						immut vec3 view = get_view();
					#endif

					immut vec3 pf = rot_trans_mmul(shadowModelViewInverse, view);
					immut vec3 pe = pf - mvInv3;
					immut f16vec3 f16_pe = f16vec3(pe);

					 // Shadow vertices will always be inside the LL distance if `shadow_rd` is smaller. The branch below should be constant.
					const bool shadow_rd_gt_ll_dist = float16_t(LL_DIST) >= shadow_rd;

					bool in_ll_dist;
					if (shadow_rd_gt_ll_dist) {
						in_ll_dist = true;
					} else {
						immut f16vec3 abs_pe = abs(f16_pe);
						immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);
						in_ll_dist = chebyshev_dist < float16_t(LL_DIST);
					}

					// Cull vertices outside `LL_DIST` in Chebyshev distance.
					if (in_ll_dist) {
						immut vec3 gb_view = pe * MV_INV;
						immut vec3 gb_ndc = proj(gbufferProjection, vec3(gb_view.xy, min(gb_view.z, 0.0)));
						immut f16vec3 clamped_pe = f16vec3(MV_INV * proj_inv(
							gbufferProjectionInverse,
							vec3(clamp(gb_ndc.xy, -1.0, 1.0), gb_ndc.z)
						)); // Player eye position clamped to frustum.

						// Add '0.5' to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
						immut float16_t offset_intensity = intensity + float16_t(0.5);

						// Distance between light and closest point in frustum.
						// In world-aligned space (player-eye) we can use Manhattan distance.
						immut float16_t light_mhtn_dist_from_bb = dot(abs(f16_pe - clamped_pe), f16vec3(1.0));

						// Cull lights too far outside frustum, using the same method as in per-subgroup culling when sampling.
						if (light_mhtn_dist_from_bb <= offset_intensity) {
							float16_t lod_dist = length(f16_pe) / float16_t(LL_DIST);

							#ifdef SOLID_TERRAIN
								immut bool is_fluid = mc_Entity.y == 1.0;
								if (is_fluid) {
									lod_dist += float16_t(LAVA_LOD_BIAS);
								}
							#else
								const bool is_fluid = false;
							#endif

							immut uvec3 seed = uvec3(ivec3((0.5 + cameraPosition) + pe));

							// LOD culling
							// Increase times two each LOD.
							// The fact that the values resulting from higher LODs are divisible by the lower ones means that no lights will appear only further away.
							if (uint8_t(pcg(seed.x + pcg(seed.y + pcg(seed.z)))) % (uint8_t(1u) << uint8_t(min(float16_t(7.0), fma(
								lod_dist,
								float16_t(LOD_FALLOFF),
								float16_t(0.5)
							)))) == uint8_t(0u)) {
								immut uvec3 offset_floor_pf = clamp(uvec3(fma(at_midBlock.xyz, vec3(1.0/64.0), 256.0 + cameraPositionFract + pf)), 0u, 511u);

								immut f16vec3 avg_col = f16vec3(gl_Color.rgb) * f16vec3(textureLod(gtexture, mc_midTexCoord, 4.0).rgb);

								push_to_llq(offset_floor_pf, avg_col, uint(intensity), is_fluid);
							}
						}
					}
				}
			}
		}
	#endif
}
