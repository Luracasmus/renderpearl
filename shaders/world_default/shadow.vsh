#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };

#ifdef CLRWL
	#define TEXTURED
#endif

#if SM_DIST == 0 || defined END || defined NETHER
	void main() {
		gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
	}
#else
	#ifdef SM_ENTITY
	#endif
	#ifdef SM_PLR
	#endif
	#ifdef SM_BLOCK_ENTITY
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

	#ifdef TEXTURED
		out VertexData { layout(location = 0) noperspective vec2 coord; } v;
	#endif

	#include "/lib/sm/distort.glsl"

	void main() {
		vec3 model = vec3(gl_Vertex);

		#ifdef CLRWL
			immut vec3 view = rot_trans_mmul(mat4(gl_ModelViewMatrix), model);
		#else
			// `gl_ModelViewMatrix` can be cut to a `mat3` since `shadowIntervalSize == 0.0`, as long as model -> view conversion only needs rotation and/or scale, which seems to always be the case in Iris.
			immut vec3 view = mat3(gl_ModelViewMatrix) * model;
		#endif
		immut vec3 clip = shadow_proj_scale.xxy * view;
		gl_Position = vec4(clip.xy * distortion(clip.xy), clip.z, 1.0);
		// RDNA4 ISA documentation states `.w` is optional, but the fallback value doesn't seem to be `1.0` on AMD drivers, so we write to it anyways.

		#ifdef TEXTURED
			v.coord = rot_trans_mmul(mat4(gl_TextureMatrix[0]), vec2(gl_MultiTexCoord0));
		#endif

		#ifdef TERRAIN
			if (LLCollect) {
				immut vec3 pf = rot_trans_mmul(shadowModelViewInverse, view);
				immut vec3 pe = pf - mvInv3;
				immut f16vec3 f16_pe = f16vec3(pe);
				immut f16vec3 abs_pe = abs(f16_pe);
				immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

				immut vec3 gb_view = pe * MV_INV;
				immut vec3 gb_ndc = proj(gbufferProjection, vec3(gb_view.xy, min(gb_view.z, 0.0)));
				immut f16vec3 clamped_pe = f16vec3(MV_INV * proj_inv(
					gbufferProjectionInverse,
					vec3(clamp(gb_ndc.xy, -1.0, 1.0), gb_ndc.z)
				)); // Player eye position clamped to frustum.

				immut float16_t intensity = max(float16_t(mc_Entity.x), float16_t(at_midBlock.w));

				// Add '0.5' to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
				immut float16_t offset_intensity = intensity + float16_t(0.5);

				// Distance between light and closest point in frustum.
				// In world-aligned space (player-eye) we can use Manhattan distance.
				immut float16_t light_mhtn_dist_from_bb = dot(abs(f16_pe - clamped_pe), f16vec3(1.0));

				if (
					// Run once per face.
					(gl_VertexID & 3) == 1 && // gl_VertexID % 4 == 1
					// Cull too weak or non-lights.
					intensity >= float16_t(MIN_LL_INTENSITY) &&
					// Cull vertices outside LL_DIST using Chebyshev distance.
					chebyshev_dist < float16_t(LL_DIST) &&
					// Cull lights too far outside frustum, using the same method as in per-work group culling when sampling.
					light_mhtn_dist_from_bb <= offset_intensity
				) {
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
		#endif
	}
#endif
