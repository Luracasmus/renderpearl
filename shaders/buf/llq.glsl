layout(std430, binding = 2) restrict buffer lightListQueue {
	uint len;
	uint[LL_CAPACITY] data;
	uint16_t[LL_CAPACITY] color;
} llq;
