uniform sampler2DShadow shadowtex0HW, shadowtex1HW;
uniform sampler2D shadowcolor0;

f16vec3 sample_sm(float16_t mul, vec3 s_scrn) {
	immut float16_t solid_vis = float16_t(textureLod(shadowtex1HW, s_scrn, 0.0));

	if (solid_vis > float16_t(0.0)) {
		immut float16_t trans_vis = float16_t(textureLod(shadowtex0HW, s_scrn, 0.0));

		f16vec3 color = (mul * solid_vis).xxx;

		if (trans_vis < solid_vis) color *= mix(f16vec3(textureLod(shadowcolor0, s_scrn.xy, 0.0).rgb), f16vec3(1.0), trans_vis);

		return color;
	} else return f16vec3(0.0);
}