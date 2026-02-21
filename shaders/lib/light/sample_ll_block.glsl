void sample_ll_block_light(
	inout f16vec3 reflected, f16vec3 color, f16vec3 rcp_color,
	float16_t intensity, float16_t offset_intensity, // `offset_intensity == intensity + 0.5` to account for the distance from the light source to the edge of the block it belongs to, where the falloff actually starts in vanilla lighting.
	f16vec3 w_tex_normal, f16vec3 w_face_normal, f16vec3 n_pe,
	float16_t roughness, float16_t f0, bool is_metal, float16_t ind_bl,
	f16vec3 w_rel_light, float16_t mhtn_dist, f16vec3 light_color, bool is_wide
) {
	immut float16_t sq_dist_light = dot(w_rel_light, w_rel_light);
	immut f16vec3 n_w_rel_light = w_rel_light * inversesqrt(sq_dist_light);

	// Make minimum falloff that of a block away of the light source when the "wide" flag (most significant bit) is set,
	// otherwise, make it half a block away (sqrt(0.25), the edge of the light source block).
	immut float16_t falloff = float16_t(1.0) / (
		max(sq_dist_light, is_wide ? float16_t(1.0) : float16_t(0.25))
	);

	immut float16_t light_level = offset_intensity - mhtn_dist;
	float16_t brightness = intensity * falloff;
	brightness *= smoothstep(float16_t(0.0), float16_t(LL_FALLOFF_MARGIN), light_level);
	brightness /= min(light_level, float16_t(15.0)) * float16_t(1.0/15.0); // Compensate for multiplication with 'light.x' later on, in order to make the falloff follow the inverse square law as much as possible.

	light_color *= brightness;

	immut float16_t tex_n_dot_l = dot(w_tex_normal, n_w_rel_light);

	f16vec3 this_reflected = ind_bl.xxx; // Very fake GI.

	if (min(tex_n_dot_l, dot(w_face_normal, n_w_rel_light)) > min_n_dot_l) {
		this_reflected += brdf(tex_n_dot_l, w_tex_normal, n_pe, n_w_rel_light, roughness, f0, is_metal, color, rcp_color);
	}

	reflected = fma(this_reflected, light_color, reflected);
}

f16vec3 mix_ll_block_light(f16vec3 fallback_block_light, float16_t chebyshev_dist, float16_t block_light_level, f16vec3 reflected) {
	// Undo the multiplication from packing light color and brightness.
	const vec3 packing_scale = vec3(15u * uvec3(31u, 63u, 31u));
	immut f16vec3 ll_block_light = f16vec3(float(DIR_BL * 3) / packing_scale) * block_light_level * reflected;

	// Mix based on distance.
	return mix(ll_block_light, fallback_block_light, smoothstep(float16_t(LL_DIST - 15), float16_t(LL_DIST), chebyshev_dist));
}
