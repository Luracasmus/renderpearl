VertexData {
	layout(location = 0, component = 0) flat uint unorm4x8_color;
	layout(location = 0, component = 1) flat uint snorm2x8_bool1_zero15_normal_emission;
	layout(location = 0, component = 2) flat uint float2x16_light;

	#ifndef NETHER
		layout(location = 1, component = 0) float s_distortion;
	#endif
} v;
