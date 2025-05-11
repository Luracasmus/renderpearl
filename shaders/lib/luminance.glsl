float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

#ifdef FLOAT16
	float16_t luminance(f16vec3 color) {
		return dot(color, f16vec3(0.299, 0.587, 0.114));
	}
#endif