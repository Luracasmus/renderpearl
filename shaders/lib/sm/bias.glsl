// vec2(normal_bias, slope_scaled_bias)
f16vec2 shadow_bias(float16_t face_n_dot_l) {
	immut float16_t cosine = saturate(face_n_dot_l); // this can probably just be max(0.0, face_n_dot_l)
	immut float16_t sine = sqrt(fma(cosine, -cosine, float16_t(1.0))); // using the Pythagorean identity
	immut float16_t tangent = sine / cosine;

	return f16vec2(vec2(-1.0, 380.0) / shadowMapResolution) * f16vec2(sine, min(float16_t(2.0), tangent));
}