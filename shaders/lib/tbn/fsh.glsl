#include "/lib/octa_normal.glsl"

in TBN {
	layout(location = 0, component = 0) flat uvec2 half2x16_octa_normal_and_tangent;
	layout(location = 0, component = 2) flat uint handedness_and_misc;
} v_tbn;

mat3 get_tbn() {
	immut f16vec2 octa_normal = f16vec2(unpackHalf2x16(v_tbn.half2x16_octa_normal_and_tangent.x));
	immut vec3 normal = vec3(normalize(octa_decode(octa_normal)));

	immut f16vec2 octa_tangent = f16vec2(unpackHalf2x16(v_tbn.half2x16_octa_normal_and_tangent.y));
	immut vec3 tangent = vec3(normalize(octa_decode(octa_tangent)));

	immut float handedness = float(v_tbn.handedness_and_misc & 1u) - 0.5; // map least significant bit, [0, 1], to [-0.5, 0.5]

	return mat3(tangent, normalize(cross(tangent, normal) * handedness), normal);
}
