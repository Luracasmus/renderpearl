/*
	Based on: https://github.com/bevyengine/bevy/blob/main/crates/bevy_pbr/src/render/pbr_lighting.wgsl

	MIT License

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

// `float16_t` adaptation from https://google.github.io/filament/Filament.html#listing_speculardfp16
float16_t d_ggx(float16_t roughness, float16_t n_dot_h, f16vec3 normal, f16vec3 half_dir) {
	immut f16vec3 n_x_h = cross(normal, half_dir);
	immut float16_t a = n_dot_h * roughness;
	immut float16_t k = roughness / fma(a, a, dot(n_x_h, n_x_h));
	immut float16_t d = k * k * float16_t(1.0/PI);
	return min(d, float16_t(65504.0));
}

float16_t v_smith_ggx_correlated(float16_t roughness, float16_t n_dot_v, float16_t n_dot_l) {
	immut float16_t a_2 = roughness * roughness;

	immut float16_t ggx_v_l_sum = dot(f16vec2(n_dot_l, n_dot_v), sqrt(f16vec2(n_dot_v, n_dot_l) * f16vec2(n_dot_v, n_dot_l) * (float16_t(1.0) - a_2) + a_2));
	return float16_t(0.5) / ggx_v_l_sum;
}

float16_t f_schlick(float16_t f0, float16_t f90, float16_t u) {
	return fma(pow(float16_t(1.0) - u, float16_t(5.0)), f90 - f0, f0);
}

// Diffuse BRDF.
float16_t fd_burley(float16_t roughness, float16_t n_dot_v, float16_t n_dot_l, float16_t l_dot_h) {
	immut float16_t f90 = float16_t(0.5) + float16_t(2.0) * roughness * l_dot_h * l_dot_h;
	immut float16_t scatter_l = f_schlick(float16_t(1.0), f90, n_dot_l);
	immut float16_t scatter_v = f_schlick(float16_t(1.0), f90, n_dot_v);
	return scatter_l * scatter_v * float16_t(1.0/PI);
}

float16_t env_brdf_approx_ab_x(float16_t roughness, float16_t n_dot_v) {
	const f16vec3 c0 = f16vec3(-1.0, -0.0275, -0.572);
	const f16vec3 c1 = f16vec3(1.0, 0.0425, 1.04);

	immut float16_t perceptual_roughness = sqrt(roughness);
	immut f16vec3 r = fma(perceptual_roughness.xxx, c0, c1);
	immut float16_t a004 = fma(min(r.x*r.x, exp2(float16_t(-9.28) * n_dot_v)), r.x, r.y);
	return fma(a004, float16_t(-1.04), r.z);
}

// All directions must be in aligned spaces.
f16vec2 brdf(
	float16_t n_dot_l, // Receiver normal dot `rec_to_lig_dir`. Must be in [0, 1].
	f16vec3 normal,
	f16vec3 obs_to_rec_dir, // Receiver direction from observer.
	f16vec3 rec_to_lig_dir, // Light direction from receiver.
	float16_t roughness
) {
	const float16_t f0 = float16_t(0.04);

	immut f16vec3 half_dir = normalize(rec_to_lig_dir - obs_to_rec_dir); // Halfway between light and observer direction from receiver.

	immut float16_t n_dot_v = saturate(dot(normal, -obs_to_rec_dir));
	immut float16_t n_dot_h = saturate(dot(normal, half_dir));
	immut float16_t l_dot_h = saturate(dot(rec_to_lig_dir, half_dir));

	immut float16_t d = d_ggx(roughness, n_dot_h, normal, half_dir);
	immut float16_t v = v_smith_ggx_correlated(roughness, n_dot_v, n_dot_l);
	const float16_t f90 = float16_t(1.0); // saturate(float16_t(50.0) * f0);
	immut float16_t f = f_schlick(f0, f90, l_dot_h);

	immut float16_t specular = (d * v) * f;

	return n_dot_l * f16vec2(
		specular * (float16_t(1.0) + (f0 / env_brdf_approx_ab_x(roughness, n_dot_v) - f0)),
		fd_burley(roughness, n_dot_v, float16_t(n_dot_l), l_dot_h)
	);
}
