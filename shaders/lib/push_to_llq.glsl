#include "/buf/llq.glsl"
#include "/lib/prng/pcg.glsl"

// Push a light to the light list queue.
void push_to_llq(uvec3 offset_floor_pf, f16vec3 srgb_avg_col, uint intensity, bool fluid) {
	immut uint packed_pf = bitfieldInsert(bitfieldInsert(offset_floor_pf.x, offset_floor_pf.y, 9, 9), offset_floor_pf.z, 18, 9);

	immut f16vec3 scaled_color = fma(linear(srgb_avg_col), f16vec3(31.0, 63.0, 31.0), f16vec3(0.5));

	#ifdef INT16
		immut uint16_t packed_color = uint16_t(scaled_color.g) | (uint16_t(scaled_color.r) << uint16_t(6u)) | (uint16_t(scaled_color.b) << uint16_t(11u));
	#else
		immut uvec3 uint_color = uvec3(scaled_color);
		immut uint16_t packed_color = uint16_t(bitfieldInsert(bitfieldInsert(uint_color.g, uint_color.r, 6, 5), uint_color.b, 11, 5));
	#endif

	#ifdef SUBGROUP_ENABLED
		// Deduplicate lights within the subgroup before pushing to the global list.
		bool is_unique = true;

		uvec4 sg_ballot = subgroupBallot(true);
		uint shuffles = subgroupBallotFindMSB(sg_ballot) - subgroupBallotFindLSB(sg_ballot);

		// Shuffle down through all active invocations.
		for (uint i = 1u; i <= shuffles; ++i) {
			immut uint other_packed_pf = subgroupShuffleDown(packed_pf, i);
			immut uint16_t other_packed_color = uint16_t(subgroupShuffleDown(packed_color, i));

			// If the invocation who's value we've aquired is within the subgroup and active
			// and has the same light position as we do and greater than or equal color value, remove our light.
			immut uint other_sg_invoc_id = gl_SubgroupInvocationID + i;
			if (
				(other_sg_invoc_id < gl_SubgroupSize) &&
				subgroupBallotBitExtract(sg_ballot, other_sg_invoc_id) &&
				other_packed_pf == packed_pf &&
				other_packed_color >= packed_color
			) {
				is_unique = false;
			}
		}

		if (is_unique) {
			sg_ballot = subgroupBallot(true);
			shuffles = subgroupBallotFindMSB(sg_ballot) - subgroupBallotFindLSB(sg_ballot);

			// Shuffle up through all remaining invocations.
			for (uint i = 1u; i <= shuffles; ++i) {
				immut uint other_packed_pf = subgroupShuffleUp(packed_pf, i);

				// We know that if an invocation with the same position at a lower index is still active,
				// that means it has a greater color value, so we remove our light.
				if (
					(gl_SubgroupInvocationID >= i) &&
					subgroupBallotBitExtract(sg_ballot, gl_SubgroupInvocationID - i) &&
					other_packed_pf == packed_pf
				) {
					is_unique = false;
				}
			}

			if (is_unique)
	#endif
			{
				#define SG_INCR_COUNTER llq.len
				uint sg_incr_i;
				#include "/lib/sg_incr.glsl"

				uint packed_data = bitfieldInsert(packed_pf,intensity, 27, 4);
				if (fluid) { packed_data |= 0x80000000u; } // Set "wide" flag for lava.

				llq.data[sg_incr_i] = packed_data;
				llq.color[sg_incr_i] = packed_color;
			}
	#ifdef SUBGROUP_ENABLED
		}
	#endif
}
