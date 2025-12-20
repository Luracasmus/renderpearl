// Specialized efficient matrix multiplication functions.

// Rotation + translation matrix multiplication.
vec2 rot_trans_mmul(mat4 rot_trans_mat, vec2 vec) {
	return mat2(rot_trans_mat) * vec + rot_trans_mat[3].xy;
}

// Rotation + translation matrix multiplication.
vec3 rot_trans_mmul(mat4 rot_trans_mat, vec3 vec) {
	return mat3(rot_trans_mat) * vec + rot_trans_mat[3].xyz;
}

// Perspective projection matrix multiplication.
vec4 proj_mmul(mat4 proj_mat, vec3 view) {
	return vec4(
		vec2(proj_mat[0].x, proj_mat[1].y) * view.xy,
		fma(proj_mat[2].z, view.z, proj_mat[3].z),
		proj_mat[2].w * view.z
	);
}

// Perspective projection matrix multiplication with divide.
vec3 proj(mat4 proj_mat, vec3 view) {
	immut vec4 clip = proj_mmul(proj_mat, view);

	return clip.xyz / clip.w;
}

// Inverse perspective projection matrix multiplication.
vec4 proj_inv_mmul(mat4 inv_proj_mat, vec3 ndc) {
	return vec4(
		vec2(inv_proj_mat[0].x, inv_proj_mat[1].y) * ndc.xy,
		inv_proj_mat[3].z,
		fma(inv_proj_mat[2].w, ndc.z, inv_proj_mat[3].w)
	);
}

// Inverse perspective projection matrix multiplication with divide.
vec3 proj_inv(mat4 inv_proj_mat, vec3 ndc) {
	immut vec4 view_undiv = proj_inv_mmul(inv_proj_mat, ndc);

	return view_undiv.xyz / view_undiv.w;
}
