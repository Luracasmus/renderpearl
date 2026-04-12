#include "/prelude/core.glsl"

/* RENDERTARGETS: 1,2 */
#ifdef SHADOWS_ENABLED
	layout(location = 1) out uvec4 colortex2;
#else
	layout(location = 1) out uvec3 colortex2;
#endif

layout(location = 0) out f16vec4 colortex1;
layout(depth_unchanged) out float gl_FragDepth;

#include "/lib/luminance.glsl"

#if DIR_SHADING != 0
	#include "/lib/octa_enc.glsl"
	#include "/lib/material/ao.glsl"
#endif

in
#include "/lib/v_data_dh.glsl"

void main() {
	if (!gl_HelperInvocation) {
		immut f16vec3 color = f16vec3(unpackUnorm4x8(v.unorm4x8_color).rgb);

		#ifdef SHADOWS_ENABLED
			colortex2.a
		#else
			colortex2.b
		#endif
			= bitfieldInsert(
				v.snorm2x8_bool1_zero15_normal_emission,
				v.snorm2x8_bool1_zero15_normal_emission,
				16, 16
			);

		{
			uint data = v.float2x16_light >> 16u; // The sign bit (#15) is always zero.

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
			// const float16_t f0 = float16_t(0.04); // TODO: Uncomment and use when f0 isn't constant.
			const float16_t roughness = float16_t(0.8);
			uint data = packUnorm4x8(f16vec4(roughness, 0.0, 0.0, 0.0));

			if (v.snorm2x8_bool1_zero15_normal_emission > 65536u) {
				data = bitfieldInsert(data, uint(255u), 16, 8); // Pack emission.
			}

			// TODO: f0 enum.

			#ifdef SHADOWS_ENABLED
				colortex2.g
			#else
				colortex2.r
			#endif
				= data;
		}

		#ifdef SHADOWS_ENABLED
			colortex2.r = floatBitsToUint(v.s_distortion);
		#endif

		colortex1 = f16vec4(color.rgb, unpackFloat2x16(v.float2x16_light).x);
	}
}
