in vec3 vaNormal;
in vec4 at_tangent;

out TBN {
	layout(location = 0, component = 0) flat vec3 normal;
	layout(location = 0, component = 3) flat float handedness;
	layout(location = 1, component = 0) flat vec3 tangent;
} tbn_comp;

void init_tbn_w() {
	tbn_comp.normal = mat3(gbufferModelViewInverse) * normalMatrix * normalize(vaNormal);
	tbn_comp.handedness = at_tangent.w;
	tbn_comp.tangent = mat3(gbufferModelViewInverse) * normalMatrix * normalize(at_tangent.xyz);
}