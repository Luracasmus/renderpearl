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
		// Thanks to FoZy STYLE (https://github.com/FoZy-STYLE / Discord: `fozystyle`)! for the snippet this is based on:
		// (Available in the shaderLABS Discord server at: https://discord.com/channels/237199950235041794/736928196162879510/1402663035314638868)
		ao_dir = cross(face_normal, f16vec3(normalize(pos_ao_ddx.w * pos_ao_ddy.xyz - pos_ao_ddy.w * pos_ao_ddx.xyz)));
	}

	return ao_dir;
}
