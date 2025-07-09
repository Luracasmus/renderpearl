#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };

uniform vec3 chunkOffset;
uniform mat4 modelViewMatrix, projectionMatrix;

in vec3 vaPosition;
in vec4 vaColor;

out VertexData { layout(location = 0, component = 0) flat uint tint; } v;

#include "/lib/mmul.glsl"
#include "/lib/srgb.glsl"
#include "/lib/un11_11_10.glsl"

void main() {
	v.tint = pack_un11_11_10(linear(vaColor.rgb));

	gl_Position = proj_mmul(projectionMatrix, rot_trans_mmul(modelViewMatrix, vaPosition + chunkOffset));
}
