// Specialized efficient matrix multiplication functions

vec2 rot_trans_mmul(mat4 rot_trans_mat, vec2 vec) {
	return mat2(rot_trans_mat) * vec + rot_trans_mat[3].xy;
}

vec3 rot_trans_mmul(mat4 rot_trans_mat, vec3 vec) {
	return mat3(rot_trans_mat) * vec + rot_trans_mat[3].xyz;
}

vec4 proj_mmul(mat4 proj_mat, vec3 view) {
	return vec4(
		vec2(proj_mat[0].x, proj_mat[1].y) * view.xy,
		fma(proj_mat[2].z, view.z, proj_mat[3].z),
		proj_mat[2].w * view.z
	);
}

vec3 proj(mat4 proj_mat, vec3 view) {
	immut vec4 clip = proj_mmul(proj_mat, view);

	return clip.xyz / clip.w;
}

vec3 proj_inv(mat4 inv_proj_mat, vec3 ndc) {
	immut vec4 view_undiv = vec4(
		vec2(inv_proj_mat[0].x, inv_proj_mat[1].y) * ndc.xy,
		inv_proj_mat[3].z,
		fma(inv_proj_mat[2].w, ndc.z, inv_proj_mat[3].w)
	);

	return view_undiv.xyz / view_undiv.w;
}

/*
	vec2 rot_trans_mmul(mat4 rot_trans_mat, vec2 vec) {
		return mat4x2(rot_trans_mat) * vec4(vec, 0.0, 1.0);
	}

	vec3 rot_trans_mmul(mat4 rot_trans_mat, vec3 vec) {
		return mat4x3(rot_trans_mat) * vec4(vec, 1.0);
	}

	vec4 proj_mmul(mat4 proj_mat, vec3 view) {
		return proj_mat * vec4(view, 1.0);
	}

	vec3 proj(mat4 proj_mat, vec3 view) {
		immut vec4 clip = proj_mmul(proj_mat, view);

		return clip.xyz / clip.w;
	}

	vec3 proj_inv(mat4 inv_proj_mat, vec3 ndc) {
		immut vec4 view_undiv = inv_proj_mat * vec4(ndc, 1.0);

		return view_undiv.xyz / view_undiv.w;
	}
*/
