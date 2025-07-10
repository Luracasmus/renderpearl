layout(std430, binding = 2) restrict buffer lightList {
	vec3 offset;

	#if defined LL_LEN16 && defined INT16
		uint16_t len;
		uint16_t _;
	#else
		uint len;
	#endif

	uint16_t[LL_CAPACITY] queue_color;
	uint[LL_CAPACITY] queue_data;
	uint16_t[LL_CAPACITY] active_color;
	uint[LL_CAPACITY] active_data;
} ll;
