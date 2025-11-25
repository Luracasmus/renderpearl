float16_t ao_curve(float16_t linear_ao) {
	return smoothstep(float16_t(0.05), float16_t(0.8), linear_ao) * linear_ao;
}
