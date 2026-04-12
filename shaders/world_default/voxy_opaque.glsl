#include "/prelude/config.glsl"
#undef SIZED_16_8
#define MINMAX_3 0
#define MUL_32x16 0
#define SUBGROUP 0
#include "/prelude/compat.glsl"
#include "/prelude/directive.glsl"
#include "/prelude/lib.glsl"

/* RENDERTARGETS: 1,2 */
layout(location = 0) out vec4 colortex1;

#ifdef SHADOWS_ENABLED
	layout(location = 1) out uvec4 colortex2;

	#include "/lib/mmul.glsl"
	#include "/lib/sm/distort.glsl"
#else
	layout(location = 1) out uvec3 colortex2;
#endif

#include "/lib/srgb.glsl"
#include "/lib/octa_enc.glsl"

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	// TODO: Implement proper material data.

	immut vec3 color = linear(parameters.sampledColour.rgb * parameters.tinting.rgb);
	immut vec2 block_sky_light = fma(parameters.lightMap, vec2(16.0/15.0), vec2(-1.0/32.0));

	colortex1 = vec4(color, block_sky_light.x);

	{
		// From cortex (https://github.com/MCRcortex):
		immut uint face = parameters.face;
		immut vec3 w_normal = vec3(uint((face >> 1u) == 2u), uint((face >> 1u) == 0u), uint((face >> 1u) == 1u)) * fma(float(int(face) & 1), 2.0, -1.0);
		immut vec2 octa_w_normal = octa_encode(w_normal);

		#ifdef SHADOWS_ENABLED
			colortex2.a
		#else
			colortex2.b
		#endif
			= packSnorm4x8(octa_w_normal.xyxy);
	}

	{
		uint data = packHalf2x16(vec2(block_sky_light.y, 0.0)); // The sign bit (#15) is always zero.

		const float ao = 1.0;
		data = bitfieldInsert(
			data, uint(fma(ao, 8191.0, 0.5)),
			15, 13
		);

		#ifdef SHADOWS_ENABLED
			colortex2.b
		#else
			colortex2.g
		#endif
			= data;
	}

	{
		const float roughness = 0.8;
		const uint data = packUnorm4x8(vec4(roughness, 0.0, 0.0, 0.0));

		// TODO: f0 enum.

		#ifdef SHADOWS_ENABLED
			colortex2.g
		#else
			colortex2.r
		#endif
			= data;
	}

	#ifdef SHADOWS_ENABLED
		immut uvec2 view_size = unpackUint2x16(uint(packedView)); // We have to do this manually to not include the uniform declaration.
		immut vec3 ndc = fma(vec3(gl_FragCoord.xy / vec2(view_size), gl_FragCoord.z), vec3(2.0), vec3(-1.0));
		immut vec3 pe = mat3(vxModelViewInv) * proj_inv(vxProjInv, ndc);
		immut vec3 abs_pe = abs(pe);
		immut float chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

		if (chebyshev_dist < float16_t(shadowDistance * shadowDistanceRenderMul)) {
			immut vec2 s_ndc = shadow_proj_scale.x * (mat3x2(shadowModelView) * (pe + vxModelViewInv[3].xyz));

			colortex2.r = floatBitsToUint(distortion(s_ndc)); // Would ideally be per-vertex but this should be mostly alright.
		}
	#endif
}
