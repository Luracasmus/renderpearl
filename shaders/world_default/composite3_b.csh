#include "/prelude/core.glsl"

/* Light Index Deduplication */

#define WG_SIZE 256
// TODO: Maybe we want this to match subgroup sizes.
#define MAX_CLUSTER_LEN 16
#define CLUSTERS_PER_WG 8

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(512, 1, 1); // TODO

uniform bool LLDedup;
uniform ivec3 previousCameraPositionInt;

#include "/lib/ll_cluster.glsl"
#include "/buf/llq.glsl"

#ifndef INT16
	coherent
#endif
#include "/buf/ll.glsl"

shared struct {
	uint[CLUSTERS_PER_WG][MAX_CLUSTER_LEN] temp_ll;
} sh;

void main() {
	// Maybe we could average all the light colors here for ambient light color.

	if (subgroupBroadcastFirst(LLDedup)) { // Deduplicate a cluster in the light list queue.
		immut uint16_t local_invocation_i = uint16_t(gl_LocalInvocationIndex);

		uint16_t cluster_invocation_i = local_invocation_i % uint16_t(MAX_CLUSTER_LEN); // TODO: I think we might be wasting the first thread in each "subgroup".
		immut uint16_t wg_cluster_i = local_invocation_i / uint16_t(MAX_CLUSTER_LEN); // Cluster index in work group.

		immut uint cluster_base = (gl_WorkGroupID.x * CLUSTERS_PER_WG + uint(wg_cluster_i)) * 16;

		immut bool is_first_cluster_invoc = cluster_invocation_i == uint16_t(0u);

		if (is_first_cluster_invoc) {
			sh.temp_ll[wg_cluster_i][0u] = 1u; // Zero the length of the temporary cluster.
		}

		cluster_invocation_i += 1u; // Since the first slot in the cluster in the actual light list is the length.


		immut uint this_cluster_len = min(llq.data[cluster_base], MAX_CLUSTER_LEN);

		// TODO: If this_cluster_len is too big...

		immut uint i = cluster_base + cluster_invocation_i; // Light index of the current thread.
		immut uint this_light = llq.data[i];

		ll.data[i] = this_light;
		/*sh.temp_ll[wg_cluster_i][cluster_invocation_i] = this_light;

		barrier();

		if (cluster_invocation_i <= this_cluster_len) {
			bool unique = true;

			//immut uint data = sh.temp_ll[wg_cluster_i][cluster_invocation_i];

			// Remove our light if there is another one at the same position with a higher color value,
			// or there is an identical light at a lower index.
			/* TODO
			for (uint16_t j = uint16_t(0u); unique && j < len; ++j) {
				immut uint16_t other_color = sh.ll_color[j];

				if (sh.temp_ll[j] == this_light && ((other_color > color) || ((other_color == color) && (j < i)))) {
					unique = false;
				}
			}/

			if (unique) {
				ll.data[cluster_base + atomicAdd(sh.temp_ll[wg_cluster_i][0u], 1u)] = this_light;
			}
		}*/

		barrier();

		if (is_first_cluster_invoc) {
			//ll.data[cluster_base] = sh.temp_ll[wg_cluster_i][0u];
			ll.data[cluster_base] = this_cluster_len;
			ll.cluster_len = llq.cluster_len; // TODO

			llq.data[cluster_base] = 1u; // 1 since the first slot is occupied by this length variable itself.

			if (gl_LocalInvocationIndex == 0u) {
				ll.origin = previousCameraPositionInt;
			}
		}
	}
}
