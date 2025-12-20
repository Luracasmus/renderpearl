#include "/prelude/core.glsl"

/* Automatic Exposure Interpolation & SSBO Clearing */

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

#if HAND_LIGHT
	writeonly
	#include "/buf/hand_light.glsl"
#endif

#if AUTO_EXP
	#include "/buf/auto_exp.glsl"
	#include "/lib/view_size.glsl"

	uniform float frameTime;
#endif

void main() {
	#if HAND_LIGHT
		hand_light.left = uvec2(0u);
		hand_light.right = uvec2(0u);
	#endif

	#if AUTO_EXP
		const vec2 composite_wg_size = vec2(32.0, 16.0); // Keep up to date.
		immut vec2 work_groups = ceil(vec2(view_size()) / composite_wg_size);

		immut float16_t geo_avg_luma = float16_t(exp(float(auto_exp.sum_log_luma) * LOG2_E / (1024.0 * work_groups.x * work_groups.y)));
		auto_exp.exposure = max(mix(
			mix(float16_t(1.0), float16_t(1.0) / geo_avg_luma, float16_t(float(1 << AUTO_EXP) * 0.001)),
			auto_exp.exposure,
			saturate(exp2(float16_t(-AUTO_EXP_SPEED) * float16_t(frameTime)))
		), float16_t(0.0));

		auto_exp.sum_log_luma = 0;
	#endif
}
