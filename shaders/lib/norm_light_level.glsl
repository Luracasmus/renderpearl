// `vec2(gl_MultiTexCoord1)` scaled to [0, 1]
f16vec2 norm_light_level() {
	immut f16vec2 lm_raw_coord = f16vec2(gl_MultiTexCoord1);

	#if defined TERRAIN && MC_VERSION >= 12110 && IRIS_VERSION < 11006
		// `gl_TextureMatrix[1]` is broken here.
		// [8, 248] -> [0, 1]
		immut f16vec2 scale = f16vec2(1.0/240.0);
		immut f16vec2 offset = f16vec2(-1.0/30.0);
	#else
		immut mat4 lm_tex_mat = mat4(gl_TextureMatrix[1]);
		immut f16vec2 scale = f16vec2(lm_tex_mat[0].x, lm_tex_mat[1].y) * f16vec2(16.0 / 15.0);
		immut f16vec2 offset = fma(f16vec2(lm_tex_mat[0].w, lm_tex_mat[1].w), f16vec2(16.0 / 15.0), f16vec2(-0.5 / 15.0));
	#endif

	return fma(lm_raw_coord, scale, offset);
}
