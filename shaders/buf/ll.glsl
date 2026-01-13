layout(std430, binding = 1) restrict buffer lightList {
	vec3 offset;
	uint16_t len;

	#ifdef INT16
		uint16_t[LL_CAPACITY] color;
	#else
		uint[uint(ceil(double(LL_CAPACITY) * 0.5Lf) + 0.5)] color; // We pack light colors in pairs.
	#endif

	uint[LL_CAPACITY] data; // This capacity could maybe be lowered.
} ll;
