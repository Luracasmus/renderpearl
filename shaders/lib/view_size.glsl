uniform int packedView;

ivec2 view_size() { return ivec2(
	packedView & 65535,
	packedView >> 16
); }

/* waiting on Iris glsl-transformer update
	u16vec2 view_size() {
		return u16vec2(
			packedView, // should be truncated for free by the cast, i think
			packedView >> 16
		);
	}
*/
