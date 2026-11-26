#include "/prelude/core.glsl"

/* SMAA Neighborhood Blending (if FFX CAS is enabled) */

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform layout(rgba16f) restrict writeonly image2D tempColorLinear;

uniform sampler2D colortex0;
uniform int packedView;

#include "/lib/post/smaa_nbh_blend.glsl"

void main() {
	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);

	imageStore(tempColorLinear, texel, f16vec4(smaa_nbh_blend(colortex0, texel), 0.0));
}
