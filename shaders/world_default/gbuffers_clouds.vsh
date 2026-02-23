#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };


out VertexData { layout(location = 0, component = 0) flat uint tint; } v;

#include "/lib/srgb.glsl"
#include "/lib/un11_11_10.glsl"

void main() {
	v.tint = pack_un11_11_10(linear(vec3(gl_Color.rgb)));

	// The code that 'ftransform()' gets transformed into in 'gbuffers_clouds.vsh' is currently impossible to implement in the core profile.
	gl_Position = ftransform();
}
