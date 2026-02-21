VertexData {
	layout(location = 0, component = 0) vec2 coord;
	layout(location = 1, component = 0) flat uint misc_packed;
	// ^uint4    bool1      unorm11 ufloat15 bool
	// ^emission handedness alpha   luma     is_water_or_metal

	#ifdef TERRAIN
		layout(location = 0, component = 2) vec2 light; // (block, sky)
		layout(location = 1, component = 1) flat uint snorm4x8_octa_tangent_normal;
		layout(location = 1, component = 2) flat uint unorm2x16_mid_coord;
		layout(location = 1, component = 3) flat uint uint2x16_face_tex_size;
		layout(location = 2, component = 0) vec3 tint;
		layout(location = 2, component = 3) float ao;

		#ifndef NETHER
			layout(location = 3, component = 0) float s_distortion;
		#endif
	#else
		layout(location = 1, component = 1) flat uint unorm4x8_tint_zero;
		layout(location = 1, component = 2) flat uint float2x16_light; // (block, sky)

		#ifndef NETHER
			layout(location = 0, component = 2) float s_distortion;
		#endif

		#ifndef NO_NORMAL
			layout(location = 1, component = 3) flat uint snorm4x8_octa_tangent_normal;

			#if NORMALS != 2 && !(NORMALS == 1 && defined MC_NORMAL_MAP)
				layout(location = 2, component = 0) flat uint unorm2x16_mid_coord;
				layout(location = 2, component = 1) flat uint uint2x16_face_tex_size;
			#endif
		#endif
	#endif
} v;
