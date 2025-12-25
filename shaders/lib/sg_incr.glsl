// Atomically increment a counter by the active invocation count
// and return a different value for every active invocation,
// starting from the initial counter value and ending at
// one below the new value.
//
// Macro `SG_INCR_COUNTER` must be set to the atomic `uint` counter,
// and `uint` variable `sg_incr_i` must exist and will be modified to the return value.
{
	#ifdef SUBGROUP_ENABLED
		immut uvec4 sg_ballot = subgroupBallot(true);
		immut uint sg_size = subgroupBallotBitCount(sg_ballot);
		immut uint sg_active_id = subgroupBallotExclusiveBitCount(sg_ballot);

		uint elected_first_i;
		if (subgroupElect()) {
			elected_first_i = atomicAdd(SG_INCR_COUNTER, sg_size);
		}
		immut uint first_i = subgroupBroadcastFirst(elected_first_i);

		sg_incr_i = first_i + sg_active_id;
	#else
		sg_incr_i = atomicAdd(SG_INCR_COUNTER, 1u);
	#endif
}
