// Helper for processing a 1 thread nbh border WITHOUT corners, computing BORDER_OP(offset) on threads at the edge of the work group, and NON_BORDER_OP otherwise
// `offset` is the offset from the thread's location in the work group to the location of the edge pixel it's processing.

{
	// TODO: make u8vec2 once it works in Iris
	// TODO: check: this may be upside down, not that it matters too much
	immut i8vec2 local = i8vec2(gl_LocalInvocationID.xy);
	immut bool down = local.y == int8_t(gl_WorkGroupSize.y - 1u);

	if (local.x == int8_t(0) && !down) { // left && !down
		BORDER_OP(ivec2(-1, 0))
	} else if (local.y == int8_t(0)) { // up && !left
		BORDER_OP(ivec2(0, -1))
	} else if (local.x == int8_t(gl_WorkGroupSize.x - 1u)) { // right && !up
		BORDER_OP(ivec2(1, 0))
	} else if (down) { // down && !right
		BORDER_OP(ivec2(0, 1))
	} else if (local == i8vec2(1, gl_WorkGroupSize.x - 2u)) { // 1 step inside lower left corner
		BORDER_OP(ivec2(-2, 1))
	} else if (local == i8vec2(1)) { // 1 step inside upper left corner
		BORDER_OP(ivec2(-1, -2))
	} else if (local == i8vec2(gl_WorkGroupSize.x - 2u, 1)) { // 1 step inside upper right corner
		BORDER_OP(ivec2(2, -1))
	} else if (local == i8vec2(gl_WorkGroupSize.xy - 2u)) { // 1 step inside lower right corner
		BORDER_OP(ivec2(1, 2))
	} else { NON_BORDER_OP }
}
