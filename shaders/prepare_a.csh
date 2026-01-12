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

uniform bool rebuildLL;
uniform vec3 cameraPositionFract, invCameraPositionDeltaInt;

#include "/buf/llq.glsl"

coherent
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

	if (rebuildLL) {
		if (is_first_invoc) { sh.culled_len = 0u; }

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

			// Copy shared list to global.
			if (unique) {
				#define SG_INCR_COUNTER sh.culled_len
				uint sg_incr_i;
				#include "/lib/sg_incr.glsl"

				ll.data[sg_incr_i] = data;
				ll.color[sg_incr_i] = color;
			}
		}

		barrier();
		groupMemoryBarrier(); // Requires 'coherent' SSBO.

		// Copy back global list to shared.
		immut uint16_t culled_len = uint16_t(subgroupBroadcastFirst(sh.culled_len));
		for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
			sh.index_data[i] = ll.data[i];
			sh.index_color[i] = ll.color[i];
		}

		barrier();

		immut vec3 ll_offset = -255.5 - cameraPositionFract - mvInv3;

		// Copy shared list into global, with lights enumeration sorted from left to right in view space to improve locality when sampling.
		// TODO: We might want to do something on the Y axis too.
		for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
			uint16_t k = uint16_t(0u);

			immut uint data = sh.index_data[i];
			immut float view_x = ((vec3(
				data & 511u,
				bitfieldExtract(data, 9, 9),
				bitfieldExtract(data, 18, 9)
			) + ll_offset) * MV_INV).x;

			for (uint16_t j = uint16_t(0u); j < culled_len; ++j) if (j != i) {
				immut uint other_data = sh.index_data[j];
				immut float other_view_x = ((vec3(
					other_data & 511u,
					bitfieldExtract(other_data, 9, 9),
					bitfieldExtract(other_data, 18, 9)
				) + ll_offset) * MV_INV).x; // TODO: Optimize

				if (other_view_x < view_x || (other_view_x == view_x && i < j)) { ++k; }
			}

			ll.data[k] = data;
			ll.color[k] = sh.index_color[i];
		}

		if (is_first_invoc) {
			llq.len = 0u;
			ll.offset = vec3(0.0);
			ll.len = culled_len;
		}
	} else if (is_first_invoc) { ll.offset += invCameraPositionDeltaInt; }
}
