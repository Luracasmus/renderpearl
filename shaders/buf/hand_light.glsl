// Each side is 4 packed 16-bit values, the R, G and B sums and the vertex count, in that order.
layout(std430, binding = 3) restrict buffer handLight {
	uvec2 left;
	uvec2 right;
} hand_light;

// Color scale to fit in 6 bits. We will be adding the color to a 16-bit sum, so this allows for up to 1024 vertices per hand.
const float hand_light_pack_scale = 63.0;
