#include "/prelude/config.glsl"
#undef SIZED_16_8
#define MINMAX_3 0
#define MUL_32x16 0
#define SUBGROUP 0
#include "/prelude/compat.glsl"
#include "/prelude/directive.glsl"

layout(location = 0) out vec4 colortex1;

#include "/lib/srgb.glsl"

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	vec4 color = parameters.sampledColour * parameters.tinting;
	color.rgb = linear(color.rgb);

	immut vec2 block_sky_light = fma(parameters.lightMap, vec2(16.0/15.0), vec2(-1.0/32.0));

	colortex1 = color;
}
