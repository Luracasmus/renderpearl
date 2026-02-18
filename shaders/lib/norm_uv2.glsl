in ivec2 vaUV2;

// `vaUV2` scaled to [0, 1]
f16vec2 norm_uv2() {
	#ifdef TERRAIN
		#if MC_VERSION >= 12110 && MC_VERSION <= 12111
			// [8, 248]
			return saturate(fma(f16vec2(vaUV2), f16vec2(1.0/240.0), f16vec2(-1.0/30.0)));
		#else
			// [8, 240]
			return saturate(fma(f16vec2(vaUV2), f16vec2(1.0/232.0), f16vec2(-1.0/29.0)));
		#endif
	#else
		// [0, 240]
		return f16vec2(vaUV2) * f16vec2(1.0/240.0);
	#endif
}
