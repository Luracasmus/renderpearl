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

uniform bool LLDedup, LLSort;
uniform vec3 cameraPositionFract;
uniform ivec3 previousCameraPositionInt, cameraPositionInt;

#include "/buf/llq.glsl"

#ifndef INT16
	coherent
#endif
#include "/buf/ll.glsl"

#include "/lib/mv_inv.glsl"

shared struct {
	uint culled_len;
	uint[ll.data.length()] index_data;
	uint16_t[ll.data.length()] index_color;
} sh;

void main() {
	// Maybe we could average all the light colors here for ambient light color.

	immut uint16_t local_invocation_i = uint16_t(gl_LocalInvocationIndex);
	immut bool is_first_invoc = local_invocation_i == uint16_t(0u);
	const uint16_t wg_size = uint16_t(gl_WorkGroupSize.x);

	if (LLDedup) { // Deduplicate the light list queue.
		if (is_first_invoc) {
			sh.culled_len = 0u;
			llq.origin = previousCameraPositionInt;
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
		}

		barrier();

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

				llq.data[sg_incr_i] = data;
				llq.color[sg_incr_i] = color;
			}
		}

		barrier();

		if (is_first_invoc) {
			llq.len = sh.culled_len;
		}
	} else if (LLSort) { // Copy the light list queue sorted into the light list, and clear the queue.
		immut uint16_t len = uint16_t(subgroupBroadcastFirst(llq.len));
		for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
			sh.index_data[i] = llq.data[i];
			sh.index_color[i] = llq.color[i];

			#ifndef INT16
				if (i < len / 2u) {
					ll.color[i] = 0u; // Clear the slot in the light list that we will be adding to later.
				}
			#endif
		}

		barrier();
		#ifndef INT16
			groupMemoryBarrier(); // Requires 'coherent' SSBO.
		#endif

		immut ivec3 ll_origin = subgroupBroadcastFirst(llq.origin);

		if (is_first_invoc) {
			llq.len = 0u;
			ll.len = len;
			ll.origin = ll_origin;
		}

		immut f16vec3 ll_origin_offset = f16vec3(ll_origin - cameraPositionInt);
		immut f16vec3 ll_offset = ll_origin_offset - f16vec3(255.5 - cameraPositionFract - mvInv3);

		immut f16vec3 mv_inv_0 = f16vec3(mvInv0);

		// Copy shared list into global, with lights enumeration sorted from left to right in view space to improve locality when sampling (especially important in forward).
		// TODO: We might want to do something on the Y axis too.
		// TODO: This seems very expensive right now with not enough benefit.
		for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
			uint16_t k = uint16_t(0u);

			immut uint data = sh.index_data[i];
			immut float16_t view_x = dot(f16vec3(
				data & 511u,
				bitfieldExtract(data, 9, 9),
				bitfieldExtract(data, 18, 9)
			) + ll_offset, mv_inv_0); // Dot with first `MV_INV` column to get `(transpose(MV_INV) * <vec>).x`.

			for (uint16_t j = uint16_t(0u); j < len; ++j) if (j != i) {
				immut uint other_data = sh.index_data[j];
				immut float16_t other_view_x = dot(f16vec3(
					other_data & 511u,
					bitfieldExtract(other_data, 9, 9),
					bitfieldExtract(other_data, 18, 9)
				) + ll_offset, mv_inv_0);

				if (other_view_x < view_x || (other_view_x == view_x && i < j)) { ++k; }
			}

			ll.data[k] = data;

			immut uint16_t color = sh.index_color[i];

			#ifdef INT16
				ll.color[k] = color;
			#else
				atomicOr(ll.color[k/2], color << (16u * (k & 1u)));
			#endif
		}
	}
}
