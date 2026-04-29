#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };

out VertexData { layout(location = 0, component = 0) flat uint tint; } v;

uniform mat4 gbufferProjection, gbufferProjectionInverse;

#include "/lib/mv_inv.glsl"
#include "/lib/mmul.glsl"
#include "/lib/srgb.glsl"
#include "/lib/un11_11_10.glsl"

void main() {
	v.tint = pack_un11_11_10(linear(vec3(gl_Color.rgb)));

	// The code that 'ftransform()' gets transformed into in 'gbuffers_clouds.vsh' is currently impossible to implement in the core profile.
	vec4 clip = ftransform();
	vec3 ndc = clip.xyz / clip.w;
	vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	vec3 pe = MV_INV * view;
	vec3 offset_view = (pe + vec3(0.0, 1.0, 0.0)) * MV_INV;
	vec4 offset_clip = proj_mmul(gbufferProjection, offset_view);


	gl_Position = offset_clip;
}
