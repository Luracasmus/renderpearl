layout(std430, binding = 2) restrict buffer lightListQueue {
	uint[16u * ll_cluster_count] data; // TODO: Use cluster size.
	uint16_t cluster_len;
} llq;
