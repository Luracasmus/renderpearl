in ivec2 vaUV2;

// `vaUV2` scaled to [0, 1] from:
// Terrain: [8, 248]
// Entities, block entities, armor, player & hand: [0, 240]
f16vec2 norm_uv2() {
	#ifdef TERRAIN
		return saturate(fma(f16vec2(vaUV2), f16vec2(1.0/240.0), f16vec2(-1.0/30.0)));
	#else
		return f16vec2(vaUV2) * f16vec2(1.0/240.0);
	#endif
}
