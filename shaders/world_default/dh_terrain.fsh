#include "/prelude/core_compatibility.glsl"

/* RENDERTARGETS: 1,2 */
#ifdef NETHER
	layout(location = 1) out uvec3 colortex2;
#else
	layout(location = 1) out uvec4 colortex2;
#endif

layout(location = 0) out f16vec4 colortex1;
layout(depth_unchanged) out float gl_FragDepth;

#include "/lib/luminance.glsl"

#if DIR_SHADING != 0
	#include "/lib/octa_normal.glsl"
	#include "/lib/material/ao.glsl"
#endif

in
#include "/lib/v_data_dh.glsl"

void main() {
	if (!gl_HelperInvocation) {
		immut f16vec3 color = f16vec3(unpackUnorm4x8(v.unorm4x8_color).rgb);

		#ifdef NETHER
			colortex2.b
		#else
			colortex2.a
		#endif
			= bitfieldInsert(
				v.snorm2x8_bool1_zero15_normal_emission,
				v.snorm2x8_bool1_zero15_normal_emission,
				16, 16
			);

		{
			uint data = v.float2x16_light >> 16u; // The sign bit (#15) is always zero.

			const float16_t ao = float16_t(1.0);
			data = bitfieldInsert(
				data, uint(fma(ao, float16_t(8191.0), float16_t(0.5))),
				15, 13
			);

			#ifdef NETHER
				colortex2.g
			#else
				colortex2.b
			#endif
				= data;
		}

		{
			const float16_t roughness = 0.8;
			uint data = packUnorm4x8(f16vec4(roughness, 0.0, 0.0, 0.0));

			if (v.snorm2x8_bool1_zero15_normal_emission > 65536u) {
				data = bitfieldInsert(data, uint(255u), 16, 8); // Pack emission.
			}

			// TODO: f0 enum.

			#ifdef NETHER
				colortex2.r
			#else
				colortex2.g
			#endif
				= data;
		}

		#ifndef NETHER
			colortex2.r = floatBitsToUint(v.s_distortion);
		#endif

		colortex1 = f16vec4(color.rgb, unpackFloat2x16(v.float2x16_light).x);
	}
}
