#include "/prelude/core_compatibility.glsl"

out gl_PerVertex { vec4 gl_Position; };

#include "/lib/mv_inv.glsl"
#include "/lib/mmul.glsl"
#include "/lib/srgb.glsl"
#include "/lib/octa_normal.glsl"

#ifndef NETHER
	uniform mat4 shadowModelView;

	#include "/lib/sm/distort.glsl"
#endif

#include "/lib/push_to_llq.glsl"

uniform bool rebuildLLQ;
uniform vec3 cameraPosition, cameraPositionFract;

out
#include "/lib/v_data_dh.glsl"

void main() {
	// TODO: Noise texture like in vanilla DH.
	immut vec3 model = vec3(gl_Vertex);
	immut vec3 view = rot_trans_mmul(mat4(gl_ModelViewMatrix), model);
	immut vec4 clip = proj_mmul(mat4(gl_ProjectionMatrix), view);
	gl_Position = clip;

	immut vec3 pe = MV_INV * view;
	immut f16vec3 f16_pe = f16vec3(pe);
	immut f16vec3 abs_pe = abs(f16_pe);
	immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

	immut mat3 normal_model_view_inverse = MV_INV * mat3(gl_NormalMatrix);
	immut f16vec3 w_normal = f16vec3(normal_model_view_inverse * normalize(vec3(gl_Normal)));
	immut uint packed_w_normal = packSnorm4x8(f16vec4(octa_encode(w_normal), f16vec2(0.0)));

	immut bool lava = dhMaterialId == DH_BLOCK_LAVA;
	immut bool emission = (lava || (dhMaterialId == DH_BLOCK_ILLUMINATED));
	v.snorm2x8_bool1_zero15_normal_emission = bitfieldInsert(packed_w_normal, uint(emission), 16, 1);

	#ifdef TRANSLUCENT
		f16vec4 color = f16vec4(gl_Color);
		color.rgb = linear(color.rgb);
		if (dhMaterialId == DH_BLOCK_WATER) {
			color.a *= float16_t(WATER_OPACITY * 0.01);
		}
		v.unorm4x8_color = packUnorm4x8(color);
	#else
		immut f16vec3 color = linear(f16vec3(gl_Color));
		v.unorm4x8_color = packUnorm4x8(f16vec4(color, 0.0));
	#endif

	// Only rebuild the index once every LL_RATE frames.
	if (rebuildLLQ) {
		immut f16vec3 view_f16 = f16vec3(view);

		if (
			// Run once per face.
			(gl_VertexID & 3) == 1 && // gl_VertexID % 4 == 1
			// Cull too weak or non-lights.
			emission &&
			// Cull vertices outside LL_DIST using Chebyshev distance.
			chebyshev_dist < float16_t(LL_DIST) &&
			// Cull behind camera outside of illumination range.
			(view_f16.z < float16_t(0.0) || dot(abs_pe, f16vec3(1.0)) <= float16_t(15.0))
		) {
			immut uvec3 seed = uvec3(ivec3((0.5 + cameraPosition) + pe));

			// LOD culling
			// Increase times two each LOD.
			// The fact that the values resulting from higher LODs are divisible by the lower ones means that no lights will appear only further away.
			if (uint8_t(pcg(seed.x + pcg(seed.y + pcg(seed.z)))) % (uint8_t(1u) << uint8_t(min(float16_t(7.0), fma(
				(lava ? float16_t(LAVA_LOD_BIAS) : float16_t(0.0)) + length(view_f16) / float16_t(LL_DIST),
				float16_t(LOD_FALLOFF),
				float16_t(0.5)
			)))) == uint8_t(0u)) {
				immut f16vec3 pf = f16_pe + f16vec3(mvInv3);
				immut uvec3 offset_floor_pf = clamp(uvec3(fma(w_normal.xyz, f16vec3(-0.5), float16_t(256.25) + f16vec3(cameraPositionFract) + pf)), 0u, 511u); // Offset by half the negative normal and add (arbitrary) 0.25 to make sure we're not exactly between two blocks.

				push_to_llq(offset_floor_pf, color.rgb, 15u, lava);
			}
		}
	}

	v.float2x16_light = packFloat2x16(f16vec2(gl_MultiTexCoord2));

	#ifndef NETHER
		if (chebyshev_dist < float16_t(shadowDistance * shadowDistanceRenderMul)) {
			immut vec2 s_ndc = shadow_proj_scale.x * (mat3x2(shadowModelView) * (pe + mvInv3));
			v.s_distortion = distortion(s_ndc);
		}
	#endif
}
