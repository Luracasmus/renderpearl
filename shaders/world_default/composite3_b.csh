#include "/prelude/core.glsl"

/* Light Index Deduplication */

// Work around compiler bug on Intel drivers.
#ifndef MC_GL_VENDOR_INTEL
	layout(local_size_x = min(gl_MaxComputeWorkGroupSize.x, LL_CAPACITY), local_size_y = 1, local_size_z = 1) in;
#elif LL_CAPACITY < 1024
	layout(local_size_x = LL_CAPACITY, local_size_y = 1, local_size_z = 1) in;
#else
	// We assume GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS >= 1024 && GL_MAX_COMPUTE_WORK_GROUP_SIZE[0] >= 1024.
	layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
#endif

const ivec3 workGroups = ivec3(1, 1, 1);

uniform bool LLDedup;
uniform ivec3 previousCameraPositionInt;

#include "/buf/llq.glsl"

#ifndef INT16
	coherent
#endif
#include "/buf/ll.glsl"

shared struct {
	uint culled_len;
	uint[ll.data.length()] index_data;
	uint16_t[ll.data.length()] index_color;
} sh;

void main() {
	// Maybe we could average all the light colors here for ambient light color.

	if (subgroupBroadcastFirst(LLDedup)) { // Deduplicate the light list queue.
		immut uint16_t local_invocation_i = uint16_t(gl_LocalInvocationIndex);
		immut bool is_first_invoc = local_invocation_i == uint16_t(0u);
		const uint16_t wg_size = uint16_t(gl_WorkGroupSize.x);

		if (is_first_invoc) {
			sh.culled_len = 0u;
		}

		// if (llq.len > ll.data.length()) { llq.len = uint16_t(0u); return; }

		#if !defined SUBGROUP_ENABLED && defined AMD_INT16
			// Work around very strange AMD compiler bug.
			// Casting to `uint16_t` before the `min` causes incorrect behavior
			// if `GL_EXT_shader_subgroup_extended_types_int16` is disabled.
			immut uint16_t len = uint16_t(min(llq.len, ll.data.length()));
		#else
			immut uint16_t len = min(uint16_t(subgroupBroadcastFirst(llq.len)), uint16_t(ll.data.length()));
		#endif

		for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
			sh.index_data[i] = llq.data[i];
			sh.index_color[i] = llq.color[i];

			#ifndef INT16
				if (i < len / 2u) {
					ll.color[i] = 0u; // Clear the slot in the light list that we will be `atomicOr`-ing into to later.
				}
			#endif
		}

		barrier();
		#ifndef INT16
			groupMemoryBarrier(); // Requires 'coherent' SSBO.
		#endif

		for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
			immut uint data = sh.index_data[i];
			immut uint16_t color = sh.index_color[i];

			bool unique = true;

			// Remove our light if there is another one at the same position with a higher color value,
			// or there is an identical light at a lower index.
			for (uint16_t j = uint16_t(0u); unique && j < len; ++j) {
				immut uint16_t other_color = sh.index_color[j];

				if (sh.index_data[j] == data && ((other_color > color) || ((other_color == color) && (j < i)))) {
					unique = false;
				}
			}

			if (unique) {
				#define SG_INCR_COUNTER sh.culled_len
				uint sg_incr_i;
				#include "/lib/sg_incr.glsl"

				ll.data[sg_incr_i] = data;

				#ifdef INT16
					ll.color[sg_incr_i] = color;
				#else
					atomicOr(ll.color[sg_incr_i/2], color << (16u * (sg_incr_i & 1u)));
				#endif
			}
		}

		barrier();

		if (is_first_invoc) {
			ll.len = uint16_t(sh.culled_len);
			ll.origin = previousCameraPositionInt;

			llq.len = 0u;
		}
	}
}
