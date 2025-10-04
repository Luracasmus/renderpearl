uniform int packedView;

u16vec2 view_size() {
	immut uint packed_view = uint(packedView);

	return unpackUint2x16(packed_view);
}
