float16_t gen_tex_ao(float16_t srgb_luma, float16_t avg_srgb_luma) {
	return saturate(float16_t(0.8) + srgb_luma - avg_srgb_luma); // TODO: Make this configurable.
}

// Must run in uniform control flow.
vec3 ao_dir(f16vec3 face_normal, vec3 pos, float linear_ao) {
	immut vec4 pos_ao = vec4(pos, linear_ao);
	immut vec4 pos_ao_ddx = dFdxCoarse(pos_ao);
	immut vec4 pos_ao_ddy = dFdyCoarse(pos_ao);

	f16vec3 ao_dir; // World space direction towards darker AO across the surface.

	if (vec2(pos_ao_ddx.w, pos_ao_ddy.w) == vec2(0.0)) {
		ao_dir = f16vec3(0.0);
	} else {
		/*
			immut vec2 norm_inv_ao_grad = normalize(-ao_grad);
			immut vec3 w_ao_screen_dir = MV_INV * vec3(norm_inv_ao_grad, 0.0); // AO darkening direction along screen in world space.
			immut bool facing_forward = dot(norm_inv_ao_grad, ndc.xy) < 0.0; // AO darkening direction faces center of screen.
			immut vec3 t_ao_dir = w_ao_screen_dir * w_tbn; // `w_tbn` is "world space" TBN.
			immut vec2 corrected_t_ao_dir = (t_ao_dir.z >= 0.0 ^^ facing_forward) ? t_ao_dir.xy : -t_ao_dir.xy; // :bentley:
			w_ao_dir = f16vec3(w_tbn * normalize(vec3(corrected_t_ao_dir, 0.0))); // AO darkening direction along surface in world space.
		*/
		/*
			vec2 e = normalize(ao_grad);
			immut vec2 ao_grad = vec2(pos_ao_ddx.w, pos_ao_ddy.w);
			w_ao_dir = MV_INV * cross(w_face_normal * MV_INV, vec3(vec2(e.y, -e.x), 0.0));
		*/

		// Thanks to FoZy STYLE (https://github.com/FoZy-STYLE / Discord: `fozystyle`)! for the snippet this is based on:
		// (Available in the shaderLABS Discord server at: https://discord.com/channels/237199950235041794/736928196162879510/1402663035314638868)
		ao_dir = cross(face_normal, f16vec3(normalize(pos_ao_ddx.w * pos_ao_ddy.xyz - pos_ao_ddy.w * pos_ao_ddx.xyz)));
	}

	return ao_dir;
}
