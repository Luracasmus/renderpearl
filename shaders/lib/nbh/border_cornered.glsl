// Helper for processing a 1 thread nbh border WITH corners, computing BORDER_OP(offset) on threads at the edge of the work group, and NON_BORDER_OP otherwise
// `offset` is the offset from the thread's location in the work group to the location of the border pixel it's processing

{
	// TODO: make u8vec2 once it works in Iris
	immut i8vec2 local = i8vec2(gl_LocalInvocationID.xy);
	immut bool up = local.y == int8_t(gl_WorkGroupSize.y - 1u);

	if (local.x == int8_t(0) && !up) { // left && !up
		BORDER_OP(ivec2(-1, 0))
	} else if (local.y == int8_t(0)) { // down && !left
		BORDER_OP(ivec2(0, -1))
	} else if (local.x == int8_t(gl_WorkGroupSize.x - 1u)) { // right && !down
		BORDER_OP(ivec2(1, 0))
	} else if (up) { // up && !right
		BORDER_OP(ivec2(0, 1))
	} else if (local.x == int8_t(1) && local.y >= int8_t(gl_WorkGroupSize.y - 3u)) { // 1 step inside upper left corner || 1 step above that
		BORDER_OP(ivec2(-2, 2))
	} else if (local.y == int8_t(1) && local.x <= int8_t(2)) { // 1 step inside lower left corner || 1 step to the right of that
		BORDER_OP(ivec2(-2, -2))
	} else if (local.x == int8_t(gl_WorkGroupSize.x - 2u) && local.y <= int8_t(2)) { // 1 step inside lower right corner || 1 step below that
		BORDER_OP(ivec2(2, -2))
	} else if (local.y == int8_t(gl_WorkGroupSize.y - 2u) && local.x >= int8_t(gl_WorkGroupSize.x - 3u)) { // 1 step inside upper right corner || 1 step to the left of that
		BORDER_OP(ivec2(2, 2))
	} else { NON_BORDER_OP }
}
