// TODO: Z-order curve or something.

const uint ll_cluster_scale = 32; // TODO: Look into if this can be changed.
//const uvec3 ll_clusters = uvec3(LL_DIST, min(LL_DIST, 384u), LL_DIST) * 2u / ll_cluster_scale; // (X, Y, Z). // TODO
const uvec3 ll_clusters = uvec3(512, 512, 512) / ll_cluster_scale; // (X, Y, Z).
const uint ll_cluster_count = ll_clusters.x * ll_clusters.y * ll_clusters.z;

uint cluster_index(
	uvec3 cluster_id // "offset floor pf" coordinates divided by cluster scale.
) {
	return
		cluster_id.x +
		cluster_id.z * ll_clusters.x +
		cluster_id.y * ll_clusters.x * ll_clusters.z;
}
