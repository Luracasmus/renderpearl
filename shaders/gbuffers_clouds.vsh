#include "/prelude/core.glsl"

uniform mat4 modelViewMatrix, projectionMatrix;

in vec3 vaPosition;
in vec4 vaColor;

out VertexData {
	layout(location = 0, component = 0) flat uint tint;
} v;

#include "/lib/mmul.glsl"
#include "/lib/srgb.glsl"
#include "/lib/un11_11_10.glsl"

void main() {
	v.tint = pack_un11_11_10(linear(vaColor.rgb));

	immut vec3 view = rot_trans_mmul(modelViewMatrix, vaPosition);

	gl_Position = proj_mmul(projectionMatrix, view);
}
