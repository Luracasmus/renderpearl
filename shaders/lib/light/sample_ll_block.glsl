void sample_ll_block_light(
	inout f16vec3 specular, inout f16vec3 diffuse,
	float16_t intensity, float16_t offset_intensity, // `offset_intensity == intensity + 0.5` to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
	f16vec3 w_tex_normal, f16vec3 w_face_normal, f16vec3 n_pe,
	float16_t roughness, float16_t ind_bl,
	f16vec3 w_rel_light, float16_t mhtn_dist, f16vec3 color, bool is_wide
) {
	immut float16_t sq_dist_light = dot(w_rel_light, w_rel_light);
	immut f16vec3 n_w_rel_light = w_rel_light * inversesqrt(sq_dist_light);

	// Make falloff start a block away of the light source when the "wide" flag (most significant bit) is set.
	immut float16_t falloff = float16_t(1.0) / (
		is_wide ? max(sq_dist_light - float16_t(1.0), float16_t(1.0)) : sq_dist_light
	);

	immut float16_t light_level = offset_intensity - mhtn_dist;
	float16_t brightness = intensity * falloff;
	brightness *= smoothstep(float16_t(0.0), float16_t(LL_FALLOFF_MARGIN), light_level);
	brightness /= min(light_level, float16_t(15.0)) * float16_t(1.0/15.0); // Compensate for multiplication with 'light.x' later on, in order to make the falloff follow the inverse square law as much as possible.
	brightness = min(brightness, float16_t(48.0)); // Prevent `float16_t` overflow later on.

	color *= brightness;

	immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_rel_light);

	float16_t light_diffuse = ind_bl; // Very fake GI.

	if (min(tex_n_dot_l, dot(w_face_normal, n_w_rel_light)) > min_n_dot_l) {
		immut f16vec2 specular_diffuse = brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, roughness);
		specular = fma(specular_diffuse.xxx, color, specular);
		light_diffuse += specular_diffuse.y;
	}

	diffuse = fma(light_diffuse.xxx, color, diffuse);
}
