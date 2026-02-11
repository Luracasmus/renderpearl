#include "/prelude/config.glsl"
#undef SIZED_16_8
#define MINMAX_3 0
#define MUL_32x16 0
#define SUBGROUP 0
#include "/prelude/compat.glsl"
#include "/prelude/directive.glsl"

layout(location = 0) out vec4 colortex1;

#ifdef NETHER
	layout(location = 1) out uvec3 colortex2;
#else
	layout(location = 1) out uvec4 colortex2;
#endif

#include "/lib/srgb.glsl"
#include "/lib/octa_normal.glsl"

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	immut vec3 color = linear(parameters.sampledColour.rgb * parameters.tinting.rgb);

	immut vec2 block_sky_light = fma(parameters.lightMap, vec2(16.0/15.0), vec2(-1.0/32.0));

	colortex1 = vec4(color, block_sky_light.x);

	{
		// From cortex (https://github.com/MCRcortex):
		immut uint face = parameters.face;
		immut vec3 w_normal = vec3(uint((face >> 1u) == 2u), uint((face >> 1u) == 0u), uint((face >> 1u) == 1u)) * (float(int(face) & 1) * 2 - 1);
		immut vec2 octa_w_normal = octa_encode(w_normal);

		#ifdef NETHER
			colortex2.b
		#else
			colortex2.a
		#endif
			= packUnorm4x8(octa_w_normal.xyxy);
	}

	{
		uint data = packHalf2x16(vec2(block_sky_light.y, 0.0)); // The sign bit (#15) is always zero.

		const float ao = 1.0;

		data = bitfieldInsert(
			data, uint(fma(ao, 8191.0, 0.5)),
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
		const float roughness = 0.8;
		const uint data = packUnorm4x8(vec4(roughness, 0.0, 0.0, 0.0));

		// TODO: f0 enum.

		#ifdef NETHER
			colortex2.r
		#else
			colortex2.g
		#endif
			= data;
	}

	#ifndef NETHER
		colortex2.r = floatBitsToUint(1.0); // TODO
	#endif
}
