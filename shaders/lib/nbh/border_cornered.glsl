// Helper for processing a 1 thread nbh border WITH corners, computing BORDER_OP(offset) on threads at the edge of the work group, and NON_BORDER_OP otherwise
// `offset` is the offset from the thread's location in the work group to the location of the border pixel it's processing.

{
	immut u8vec2 local = u8vec2(gl_LocalInvocationID.xy);
	immut bool up = local.y == uint8_t(gl_WorkGroupSize.y - 1u);

	if (local.x == uint8_t(0u) && !up) { // left && !up
		BORDER_OP(ivec2(-1, 0))
	} else if (local.y == uint8_t(0u)) { // down && !left
		BORDER_OP(ivec2(0, -1))
	} else if (local.x == uint8_t(gl_WorkGroupSize.x - 1u)) { // right && !down
		BORDER_OP(ivec2(1, 0))
	} else if (up) { // up && !right
		BORDER_OP(ivec2(0, 1))
	} else if (local.x == uint8_t(1u) && local.y >= uint8_t(gl_WorkGroupSize.y - 3u)) { // 1 step inside upper left corner || 1 step above that
		BORDER_OP(ivec2(-2, 2))
	} else if (local.y == uint8_t(1u) && local.x <= uint8_t(2u)) { // 1 step inside lower left corner || 1 step to the right of that
		BORDER_OP(ivec2(-2, -2))
	} else if (local.x == uint8_t(gl_WorkGroupSize.x - 2u) && local.y <= uint8_t(2u)) { // 1 step inside lower right corner || 1 step below that
		BORDER_OP(ivec2(2, -2))
	} else if (local.y == uint8_t(gl_WorkGroupSize.y - 2u) && local.x >= uint8_t(gl_WorkGroupSize.x - 3u)) { // 1 step inside upper right corner || 1 step to the left of that
		BORDER_OP(ivec2(2, 2))
	} else { NON_BORDER_OP }
}
