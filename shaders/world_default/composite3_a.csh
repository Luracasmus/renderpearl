#include "/prelude/core.glsl"

/* Automatic Exposure Interpolation & SSBO Clearing */

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

#if HAND_LIGHT
	uniform int handLightPackedLR;

	writeonly
	#include "/buf/hl.glsl"

	#include "/buf/hlq.glsl"

	uint process_hand_light(uvec2 buf_data) {
		immut u16vec2 rg = unpackUint2x16(buf_data.x);
		immut u16vec2 b_count = unpackUint2x16(buf_data.y);

		immut uvec3 scaled_color = uvec3(fma(
			f16vec3(rg, b_count.x),
			f16vec3(vec3(2047.0, 2047.0, 1023.0) / hand_light_pack_scale) / max(float16_t(b_count.y), float16_t(0.0078125)),
			f16vec3(0.5)
		));
		return bitfieldInsert(bitfieldInsert(scaled_color.r, scaled_color.g, 11, 11), scaled_color.b, 22, 10);
	}
#endif

#if AUTO_EXP
	#include "/buf/auto_exp.glsl"
	#include "/lib/view_size.glsl"

	uniform float frameTime;
#endif

void main() {
	// TODO: Test merging this into prepare.csh

	#if HAND_LIGHT
		if (handLightPackedLR != 0) {
			immut u16vec2 hand_light_lr = unpackUint2x16(uint(handLightPackedLR));
			immut bvec2 active_lr = notEqual(hand_light_lr, u16vec2(0u));

			uint left;
			if (active_lr.x) {
				left = process_hand_light(hlq.uint2x16_left);
				hlq.uint2x16_left = uvec2(0u);
			} else {
				left = 0u;
			}
			hl.unorm11_11_10_left = left;

			uint right;
			if (active_lr.y) {
				right = process_hand_light(hlq.uint2x16_right);
				hlq.uint2x16_right = uvec2(0u);
			} else {
				right = 0u;
			}
			hl.unorm11_11_10_right = right;
		}
	#endif

	#if AUTO_EXP
		const vec2 composite_wg_size = vec2(8.0, 16.0); // Keep up to date.
		immut vec2 work_groups = ceil(vec2(view_size()) / composite_wg_size);

		immut float16_t geo_avg_luma = float16_t(exp(float(subgroupBroadcastFirst(auto_exp.sum_log_luma)) * LOG2_E / (1024.0 * work_groups.x * work_groups.y)));
		auto_exp.exposure = max(mix(
			mix(float16_t(1.0), float16_t(1.0) / geo_avg_luma, float16_t(float(1 << AUTO_EXP) * 0.001)),
			float16_t(subgroupBroadcastFirst(auto_exp.exposure)),
			saturate(exp2(float16_t(-AUTO_EXP_SPEED) * float16_t(frameTime)))
		), float16_t(0.0));

		auto_exp.sum_log_luma = 0;
	#endif
}
