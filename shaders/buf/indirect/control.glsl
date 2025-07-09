layout(std430, binding = 4) restrict buffer indirectControl {
	#ifdef INT16
		i16vec2 coords[];
	#else
		uint coords[];
	#endif
} indirect_control;
