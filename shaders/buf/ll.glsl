layout(std430, binding = 1) restrict buffer lightList {
	vec3 offset;
	uint16_t len;
	uint16_t[LL_CAPACITY] color;
	uint[LL_CAPACITY] data; // This capacity could maybe be lowered.
} ll;
