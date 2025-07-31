#include "/lib/octa_normal.glsl"

in TBN {
	layout(location = 0, component = 0) flat uint half2x16_octa_normal;
	layout(location = 0, component = 1) flat uint half2x16_octa_tangent;
	layout(location = 0, component = 2) flat uint handedness_and_misc;
} v_tbn;
