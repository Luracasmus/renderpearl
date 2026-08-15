VertexData {
	layout(location = 0, component = 0) vec2 coord;
	layout(location = 1, component = 0) flat uint misc_packed;
	// ^uint4    bool1      unorm11 none15 bool
	// ^emission handedness alpha   none   is_water_or_metal

	#ifdef TERRAIN
		layout(location = 0, component = 2) vec2 light; // (block, sky)
		layout(location = 1, component = 1) flat uint snorm4x8_octa_tangent_normal;
		layout(location = 1, component = 2) flat uint unorm2x16_mid_coord;
		layout(location = 1, component = 3) flat uint uint2x16_face_tex_size;
		layout(location = 2, component = 0) vec3 tint;
		layout(location = 2, component = 3) float ao;

		#ifdef SHADOWS_ENABLED
			layout(location = 3, component = 0) float s_distortion;
		#endif
	#else
		#ifdef SHADOWS_ENABLED
			layout(location = 0, component = 2) float s_distortion;
		#endif

		layout(location = 1, component = 1) flat uint unorm4x8_tint_zero;
		layout(location = 1, component = 2) flat uint unorm2x16_mid_coord;
		layout(location = 1, component = 3) flat uint uint2x16_face_tex_size;

		#ifndef CLRWL
			layout(location = 2, component = 0) flat uint float2x16_light; // (block, sky)
		#endif

		#ifndef NO_NORMAL
			layout(location = 2, component =
				#ifdef CLRWL
					0
				#else
					1
				#endif
			) flat uint snorm4x8_octa_tangent_normal;
		#endif
	#endif
} v;
