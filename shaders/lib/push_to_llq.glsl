#include "/lib/ll_cluster.glsl"
#include "/buf/llq.glsl"
#include "/lib/prng/pcg.glsl"

// Push a light to the light list queue.
void push_to_llq(uvec3 offset_floor_pf, f16vec3 srgb_avg_col, uint intensity, bool fluid) {
	immut uint packed_global_pf = bitfieldInsert(bitfieldInsert(offset_floor_pf.x, offset_floor_pf.y, 9, 9), offset_floor_pf.z, 18, 9);

	immut f16vec3 scaled_color = fma(linear(srgb_avg_col), f16vec3(15.0), f16vec3(0.5));

	#ifdef INT16
		immut uint16_t packed_color = uint16_t(scaled_color.g) | (uint16_t(scaled_color.r) << uint16_t(4u)) | (uint16_t(scaled_color.b) << uint16_t(8u));
	#else
		immut uvec3 uint_color = uvec3(scaled_color);
		immut uint16_t packed_color = uint16_t(bitfieldInsert(bitfieldInsert(uint_color.g, uint_color.r, 4, 4), uint_color.b, 8, 4));
	#endif

	#ifdef SUBGROUP_ENABLED
		// Deduplicate lights within the subgroup before pushing to the global list.
		bool is_unique = true;

		uvec4 sg_ballot = subgroupBallot(true);
		uint shuffles = subgroupBallotFindMSB(sg_ballot) - subgroupBallotFindLSB(sg_ballot);

		// Shuffle down through all active invocations.
		for (uint i = 1u; i <= shuffles; ++i) {
			immut uint other_packed_global_pf = subgroupShuffleDown(packed_global_pf, i);
			immut uint16_t other_packed_color = uint16_t(subgroupShuffleDown(packed_color, i));

			// If the invocation who's value we've aquired is within the subgroup and active
			// and has the same light position as we do and greater than or equal color value, remove our light.
			immut uint other_sg_invoc_id = gl_SubgroupInvocationID + i;
			if (
				(other_sg_invoc_id < gl_SubgroupSize) &&
				subgroupBallotBitExtract(sg_ballot, other_sg_invoc_id) &&
				(other_packed_global_pf == packed_global_pf) &&
				(other_packed_color >= packed_color)
			) {
				is_unique = false;
			}
		}

		if (is_unique) {
			sg_ballot = subgroupBallot(true);
			shuffles = subgroupBallotFindMSB(sg_ballot) - subgroupBallotFindLSB(sg_ballot);

			// Shuffle up through all remaining invocations.
			for (uint i = 1u; i <= shuffles; ++i) {
				immut uint other_packed_global_pf = subgroupShuffleUp(packed_global_pf, i);

				// We know that if an invocation with the same position at a lower index is still active,
				// that means it has a greater color value, so we remove our light.
				if (
					(gl_SubgroupInvocationID >= i) &&
					subgroupBallotBitExtract(sg_ballot, gl_SubgroupInvocationID - i) &&
					other_packed_global_pf == packed_global_pf
				) {
					is_unique = false;
				}
			}

			if (is_unique)
	#endif
			{
				immut uvec3 cluster_id = offset_floor_pf / ll_cluster_scale;
				immut uint cluster_base = cluster_index(cluster_id) * uint(16);
				immut uint cluster_i = atomicAdd(llq.data[cluster_base], 1u); // TODO: Clamp?

				immut uvec3 local_pf = offset_floor_pf % ll_cluster_scale;
				uint packed_data = bitfieldInsert(bitfieldInsert(local_pf.x, local_pf.y, 5, 5), local_pf.z, 10, 5); // 14:0
				packed_data = bitfieldInsert(packed_data, intensity, 15, 4); // 18:15
				packed_data = bitfieldInsert(packed_data, packed_color, 16, 15); // 30:19

				if (fluid) { packed_data |= 0x80000000u; } // Set "wide" flag for lava (bit 31).

				llq.data[cluster_base + cluster_i] = packed_data;
			}
	#ifdef SUBGROUP_ENABLED
		}
	#endif
}
