#include "/prelude/core.glsl"

/* Light Index Deduplication */

/*
	// work around compiler bug on Intel drivers (and I think Mesa and maybe elsewhere too)
	#if defined MC_GL_VENDOR_NVIDIA || defined MC_GL_VENDOR_AMD || defined MC_GL_VENDOR_ATI
		layout(local_size_x = min(gl_MaxComputeWorkGroupSize.x, LL_CAPACITY), local_size_y = 1, local_size_z = 1) in;
	#elif LL_CAPACITY < 1024
		layout(local_size_x = LL_CAPACITY, local_size_y = 1, local_size_z = 1) in;
	#else
		// we assume GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS >= 1024 && GL_MAX_COMPUTE_WORK_GROUP_SIZE[0] >= 1024
		layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
	#endif

	const ivec3 workGroups = ivec3(1, 1, 1);

	uniform bool rebuildIndex;
	uniform vec3 cameraPositionFract, invCameraPositionDeltaInt;
	uniform mat4 gbufferModelViewInverse;

	coherent
	#include "/buf/ll.glsl"

	shared uint sh_culled_len;
	shared uint[index.data.length()] sh_data;
	shared uint16_t[index.data.length()] sh_color;

	void main() {
		// maybe we could average all the light colors here for ambient light color

		immut uint16_t local_invocation_i = uint16_t(gl_LocalInvocationIndex);
		const uint16_t wg_size = uint16_t(gl_WorkGroupSize.x);

		if (rebuildIndex) {
			if (local_invocation_i == uint16_t(0u)) sh_culled_len = 0u;

			// if (index.queue > index.data.length()) { index.len = uint16_t(0u); return; }

			immut uint16_t len = min(uint16_t(index.queue), uint16_t(index.data.length()));
			for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
				sh_data[i] = index.data[i];
				sh_color[i] = index.color[i];
			}

			barrier();

			for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
				immut uint data = sh_data[i];
				immut uint16_t color = sh_color[i];

				bool unique = true;

				// cull identical lights
				for (uint16_t j = uint16_t(0u); unique && j < i; ++j) if (sh_data[j] == data && sh_color[j] == color) unique = false;

				// cull different colored lights at the same pos, comparing the color bits to make it deterministic
				for (uint16_t j = uint16_t(0u); unique && j < len; ++j) if (sh_data[j] == data && sh_color[j] < color) unique = false;

				// copy shared index to global
				if (unique) {
					immut uint i = atomicAdd(sh_culled_len, 1u);
					index.data[i] = data;
					index.color[i] = color;
				}
			}

			barrier();
			groupMemoryBarrier(); // requires 'coherent' SSBO

			// copy back global index to shared
			immut uint16_t culled_len = uint16_t(sh_culled_len);
			for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
				sh_data[i] = index.data[i];
				sh_color[i] = index.color[i];
			}

			barrier();

			immut vec3 index_offset = -255.5 - cameraPositionFract - gbufferModelViewInverse[3].xyz;

			// copy shared index into global, with lights sorted closest to furthest
			for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
				uint16_t k = uint16_t(0u);

				immut uint data = sh_data[i];
				immut vec3 pe = vec3(
					data & 511u,
					bitfieldExtract(data, 9, 9),
					bitfieldExtract(data, 18, 9)
				) + index_offset;
				immut float sq_dist = dot(pe, pe);

				for (uint16_t j = uint16_t(0u); j < culled_len; ++j) if (j != i) {
					immut uint other_data = sh_data[j];
					immut vec3 other_pe = vec3(
						other_data & 511u,
						bitfieldExtract(other_data, 9, 9),
						bitfieldExtract(other_data, 18, 9)
					) + index_offset;

					if (dot(other_pe, other_pe) < sq_dist) ++k;
				}

				index.data[k] = data;
				index.color[k] = sh_color[i];
			}

			if (local_invocation_i == uint16_t(0u)) {
				index.queue = 0u;
				index.offset = vec3(0.0);
				index.len = culled_len;
			}
		} else if (local_invocation_i == uint16_t(0u)) index.offset += invCameraPositionDeltaInt;
	}
*/

// work around compiler bug on Intel drivers (and I think Mesa and maybe elsewhere too)
#if defined MC_GL_VENDOR_NVIDIA || defined MC_GL_VENDOR_AMD || defined MC_GL_VENDOR_ATI
	layout(local_size_x = min(gl_MaxComputeWorkGroupSize.x, LL_CAPACITY), local_size_y = 1, local_size_z = 1) in;
#elif LL_CAPACITY < 1024
	layout(local_size_x = LL_CAPACITY, local_size_y = 1, local_size_z = 1) in;
#else
	// we assume GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS >= 1024 && GL_MAX_COMPUTE_WORK_GROUP_SIZE[0] >= 1024
	layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
#endif

const ivec3 workGroups = ivec3(1, 1, 1);

uniform int llCycle;
uniform vec3 invCameraPositionDeltaInt;

#define LL_LEN16
#define QUEUE16
coherent
#include "/buf/ll.glsl"

shared uint sh_culled_len;
shared uint[LL_CAPACITY] sh_data;
shared uint16_t[LL_CAPACITY] sh_color;

void main() {
	// maybe we could average all the light colors here for ambient light color

	immut uint16_t local_invocation_i = uint16_t(gl_LocalInvocationIndex);
	const uint16_t wg_size = uint16_t(gl_WorkGroupSize.x);

	immut uint16_t ll_cycle = uint16_t(llCycle);

	if (ll_cycle < uint16_t(6u)) {
		if (local_invocation_i == uint16_t(0u)) sh_culled_len = 0u;

		// if (index.queue > index.data.length()) { index.len = uint16_t(0u); return; }

		immut uint16_t queue = min(ll.len, uint16_t(LL_CAPACITY));

		// copy queue to shared
		for (uint16_t i = local_invocation_i; i < queue; i += wg_size) {
			sh_data[i] = ll.queue_data[i];
			sh_color[i] = ll.queue_color[i];
		}

		barrier();

		immut bool ll_already_exists = ll_cycle != uint16_t(0u);

		for (uint16_t i = local_invocation_i; i < queue; i += wg_size) {
			immut uint data = sh_data[i];
			immut uint16_t color = sh_color[i];

			bool unique = true;

			// cull identical lights
			for (uint16_t j = uint16_t(0u); unique && j < i; ++j) if (sh_data[j] == data && sh_color[j] == color) unique = false;

			// cull different colored lights at the same pos, comparing the color bits to make it deterministic
			for (uint16_t j = uint16_t(0u); unique && j < queue; ++j) if (sh_data[j] == data && sh_color[j] < color) unique = false;

			// copy shared back to queue
			if (unique) {
				immut uint i = atomicAdd(sh_culled_len, 1u);

				if (ll_already_exists) {
					ll.queue_data[i] = data;
					ll.queue_color[i] = color;
				} else {
					ll.active_data[i] = data;

					immut uint16_t directions = uint16_t(1u) << (ll_cycle - uint16_t(1u));
					immut f16vec3 unpacked_color = f16vec3(
						(color >> uint16_t(4u)) & uint16_t(7u),
						color & uint16_t(15u),
						(color >> uint16_t(7u)) & uint16_t(7u)
					) * f16vec3(1.0 / vec3(31.0, 63.0, 31.0));
					immut f16vec3 scaled_color = fma(unpacked_color, f16vec3(7.0, 15.0, 7.0), f16vec3(0.5));
					ll.active_color[i] = uint16_t(scaled_color.g)
						| (uint16_t(scaled_color.r) << uint16_t(4u))
						| (uint16_t(scaled_color.b) << uint16_t(7u))
						| (directions << uint16_t(10u));
				}
			}
		}

		immut uint16_t culled_len = uint16_t(sh_culled_len);

		barrier();

		if (ll_already_exists) {
			groupMemoryBarrier(); // requires 'coherent' SSBO

			// copy culled queue back to shared
			for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
				sh_data[i] = ll.queue_data[i];
				sh_color[i] = ll.queue_color[i];
			}

			barrier();

			// merge shared with active
			for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
				immut uint data = ll.active_data[i];

				bool unique = true;

				for (uint16_t j = uint16_t(0u); unique && j < culled_len; ++j) if (sh_data[j] == data) {
					immut uint16_t packed_color0 = ll.active_color[j];
					immut uint16_t packed_color1 = sh_color[j];

					immut f16vec3 color0 = f16vec3(
						(packed_color0 >> uint16_t(4u)) & uint16_t(7u),
						packed_color0 & uint16_t(15u),
						(packed_color0 >> uint16_t(7u)) & uint16_t(7u)
					) * f16vec3(1.0 / vec3(7.0, 15.0, 7.0));
					immut f16vec3 color1 = f16vec3(
						bitfieldExtract(uint(packed_color1), 6, 5),
						packed_color1 & uint16_t(63u),
						packed_color1 >> uint16_t(11u)
					) * f16vec3(1.0 / vec3(31.0, 63.0, 31.0));

					immut uint16_t directions0 = packed_color0 >> uint16_t(10u);

					immut f16vec3 scaled_color2 = fma(
						mix(color0, color1, float16_t(1.0) / float16_t(uint16_t(bitCount(directions0)) + uint16_t(1u))),
						f16vec3(7.0, 15.0, 7.0),
						f16vec3(0.5)
					);

					immut uint16_t directions1 = uint16_t(1u) << (ll_cycle - uint16_t(1u));

					immut uint16_t packed_color2 = uint16_t(scaled_color2.g)
						| (uint16_t(scaled_color2.r) << uint16_t(4u))
						| (uint16_t(scaled_color2.b) << uint16_t(7u))
						| ((directions0 & directions1) << uint16_t(10u));

					ll.active_color[j] = packed_color2;

					unique = false;
				}

				if (unique) {
					immut uint i = atomicAdd(sh_culled_len, 1u);

					ll.active_data[i] = data;
					ll.active_color[i] = sh_color[i];
				}
			}
		}

		barrier();

		if (local_invocation_i == uint16_t(0u)) {
			ll.len = uint16_t(sh_culled_len);
			ll.offset = ll_already_exists ? ll.offset + invCameraPositionDeltaInt : vec3(0.0);
		}
	} else if (local_invocation_i == uint16_t(0u)) ll.offset += invCameraPositionDeltaInt;
}
