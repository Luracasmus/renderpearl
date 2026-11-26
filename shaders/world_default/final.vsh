#include "/prelude/core.glsl"

void main() {
	gl_Position = vec4(fma(gl_Vertex.xy, vec2(2.0), vec2(-1.0)), 0.0, 1.0);
}
