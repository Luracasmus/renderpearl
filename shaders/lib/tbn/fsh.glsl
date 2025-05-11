in TBN {
	layout(location = 0, component = 0) flat vec3 normal;
	layout(location = 0, component = 3) flat float handedness;
	layout(location = 1, component = 0) flat vec3 tangent;
} tbn_comp;

mat3 get_tbn() {
	return mat3(tbn_comp.tangent, normalize(cross(tbn_comp.tangent, tbn_comp.normal) * tbn_comp.handedness), tbn_comp.normal);
}