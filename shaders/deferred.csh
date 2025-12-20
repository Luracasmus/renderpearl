#include "/prelude/core.glsl"

/* Light Index Deduplication */

// Work around compiler bug on Intel drivers (and I think Mesa and maybe elsewhere too).
#if defined MC_GL_VENDOR_NVIDIA || defined MC_GL_VENDOR_AMD || defined MC_GL_VENDOR_ATI
	layout(local_size_x = min(gl_MaxComputeWorkGroupSize.x, LL_CAPACITY), local_size_y = 1, local_size_z = 1) in;
#elif LL_CAPACITY < 1024
	layout(local_size_x = LL_CAPACITY, local_size_y = 1, local_size_z = 1) in;
#else
	// We assume GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS >= 1024 && GL_MAX_COMPUTE_WORK_GROUP_SIZE[0] >= 1024.
	layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
#endif

const ivec3 workGroups = ivec3(1, 1, 1);

uniform bool rebuildLL;
uniform vec3 cameraPositionFract, invCameraPositionDeltaInt, mvInv3;

coherent
#include "/buf/ll.glsl"

shared uint sh_culled_len;
shared uint[ll.data.length()] sh_index_data;
shared uint16_t[ll.data.length()] sh_index_color;

void main() {
	// Maybe we could average all the light colors here for ambient light color.

	immut uint16_t local_invocation_i = uint16_t(gl_LocalInvocationIndex);
	immut bool is_first_invoc = local_invocation_i == uint16_t(0u);
	const uint16_t wg_size = uint16_t(gl_WorkGroupSize.x);

	if (rebuildLL) {
		if (is_first_invoc) { sh_culled_len = 0u; }

		// if (ll.queue > ll.data.length()) { ll.len = uint16_t(0u); return; }

		immut uint16_t len = min(uint16_t(ll.queue), uint16_t(ll.data.length()));
		for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
			sh_index_data[i] = ll.data[i];
			sh_index_color[i] = ll.color[i];
		}

		barrier();

		for (uint16_t i = local_invocation_i; i < len; i += wg_size) {
			immut uint data = sh_index_data[i];
			immut uint16_t color = sh_index_color[i];

			bool unique = true;

			// Cull identical lights.
			for (uint16_t j = uint16_t(0u); unique && j < i; ++j) {
				if (sh_index_data[j] == data && sh_index_color[j] == color) { unique = false; }
			}

			// Cull different colored lights at the same pos, comparing the color bits to make it deterministic.
			for (uint16_t j = uint16_t(0u); unique && j < len; ++j) {
				if (sh_index_data[j] == data && sh_index_color[j] < color) { unique = false; }
			}

			// Copy shared list to global.
			if (unique) {
				immut uint i = atomicAdd(sh_culled_len, 1u);
				ll.data[i] = data;
				ll.color[i] = color;
			}
		}

		barrier();
		groupMemoryBarrier(); // Requires 'coherent' SSBO.

		// Copy back global list to shared.
		immut uint16_t culled_len = uint16_t(sh_culled_len);
		for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
			sh_index_data[i] = ll.data[i];
			sh_index_color[i] = ll.color[i];
		}

		barrier();

		immut vec3 index_offset = -255.5 - cameraPositionFract - mvInv3;

		// Copy shared list into global, with lights enumeration sorted closest to furthest.
		for (uint16_t i = local_invocation_i; i < culled_len; i += wg_size) {
			uint16_t k = uint16_t(0u);

			immut uint data = sh_index_data[i];
			immut vec3 pe = vec3(
				data & 511u,
				bitfieldExtract(data, 9, 9),
				bitfieldExtract(data, 18, 9)
			) + index_offset;
			immut float sq_dist = dot(pe, pe);

			for (uint16_t j = uint16_t(0u); j < culled_len; ++j) if (j != i) {
				immut uint other_data = sh_index_data[j];
				immut vec3 other_pe = vec3(
					other_data & 511u,
					bitfieldExtract(other_data, 9, 9),
					bitfieldExtract(other_data, 18, 9)
				) + index_offset;

				immut float other_sq_dist = dot(other_pe, other_pe);
				if (other_sq_dist < sq_dist || (other_sq_dist == sq_dist && i < j)) { ++k; }
			}

			ll.data[k] = data;
			ll.color[k] = sh_index_color[i];
		}

		if (is_first_invoc) {
			ll.queue = 0u;
			ll.offset = vec3(0.0);
			ll.len = culled_len;
		}
	} else if (is_first_invoc) { ll.offset += invCameraPositionDeltaInt; }
}
