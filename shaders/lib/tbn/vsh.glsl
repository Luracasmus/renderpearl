#include "/lib/octa_normal.glsl"

in vec3 vaNormal;
in vec4 at_tangent;

out TBN {
	layout(location = 0, component = 0) flat uvec2 half2x16_octa_normal_and_tangent;
	layout(location = 0, component = 2) flat uint handedness_and_misc;
} v_tbn;

// this must run before all other uses of `v_tbn.handedness_and_misc`, and the least significant bit may not be modified after this
void init_tbn(f16vec3 normal, f16vec3 tangent) {
	v_tbn.half2x16_octa_normal_and_tangent = uvec2(
		packHalf2x16(octa_encode(normal)),
		packHalf2x16(octa_encode(tangent))
	);
	v_tbn.handedness_and_misc = uint(fma(at_tangent.w, 0.5, 1.0)); // map at_tangent.w, [-1, 1], to rounded [0, 1] and store in least significant bit
}
