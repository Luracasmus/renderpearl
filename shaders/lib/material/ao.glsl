float16_t corner_ao_curve(float16_t linear_ao) {
	return smoothstep(float16_t(0.05), float16_t(0.8), linear_ao) * linear_ao;
}

float16_t gen_tex_ao(float16_t srgb_luma, float16_t avg_srgb_luma) {
	return saturate(float16_t(0.8) + srgb_luma - avg_srgb_luma); // TODO: Make this configurable.
}

#if DIR_SHADING != 0
	float16_t dir_shading(f16vec3 w_tex_normal) {
		const float dir_shading = 0.1 * float(10 - DIR_SHADING);
		return clamp(dot(f16vec3(abs(w_tex_normal.xz), w_tex_normal.y), f16vec3(dir_shading, 0.5 * dir_shading, 1.0)), 0.25 * dir_shading, 1.0);
	}
#endif
