#include "/prelude/core.glsl"

/* Deferred Indirect Dispatch */

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform sampler2D depthtex0;

uniform layout(rgba16f) restrict writeonly image2D colorimg1;

#include "/buf/indirect/dispatch.glsl"

writeonly
#include "buf/indirect/control.glsl"

#ifndef NETHER
	uniform float frameTimeCounter;

	#include "/lib/prng/pcg.glsl"
	#include "/lib/skylight.glsl"

	#ifdef END
		#include "/lib/prng/fast_rand.glsl"
	#else
		uniform vec3 sunDirectionPlr;
	#endif
#endif

#include "/lib/mmul.glsl"
#include "/lib/view_size.glsl"
#include "/lib/srgb.glsl"
#include "/lib/fog.glsl"

shared bool sh_geometry;

void main() {
	if (gl_LocalInvocationIndex == 0u) sh_geometry = false;
	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);

	barrier();

	immut float depth = texelFetch(depthtex0, texel, 0).r;
	immut bool geometry = depth < 1.0;
	if (subgroupAny(geometry)) if (subgroupElect()) sh_geometry = true;

	barrier();

	if (gl_LocalInvocationIndex == 0u) if (sh_geometry) {
		#ifdef INT16
			immut i16vec2 packed_texel = i16vec2(gl_WorkGroupSize.xy) * i16vec2(gl_WorkGroupID.xy);
		#else
			immut uvec2 first_texel = multiply32x16(gl_WorkGroupSize.xy, gl_WorkGroupID.xy);
			immut uint packed_texel = bitfieldInsert(first_texel.x, first_texel.y, 16, 16);
		#endif

		indirect_control.coords[atomicAdd(indirect_dispatch.work_groups.x, 1u)] = packed_texel;
	}

	if (!geometry) {
		immut vec2 texel_size = 1.0 / vec2(view_size());
		immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
		immut vec3 ndc = fma(vec3(coord, depth), vec3(2.0), vec3(-1.0));
		immut vec3 pe = mat3(gbufferModelViewInverse) * proj_inv(gbufferProjectionInverse, ndc);
		immut vec3 n_pe = normalize(pe);

		#ifdef NETHER
			immut f16vec3 fog_col = linear(f16vec3(fogColor));
		#elif defined END
			immut f16vec3 fog_col = sky(n_pe);
		#else
			immut float16_t sky_fog_val = sky_fog(float16_t(n_pe.y));
			immut f16vec3 fog_col = sky(sky_fog_val, n_pe, sunDirectionPlr);
		#endif

		f16vec3 color;

		#if defined NETHER || defined END
			color = fog_col;
		#else
			immut uvec2 seed = uvec2(ivec2(n_pe.xz * 1000.0 + sin(frameTimeCounter * 1000.0) * 0.2));

			immut float16_t stars = max(
				float16_t(1.0) - sky_fog_val - float16_t(skyState.x),
				float16_t(0.0)
			) * smoothstep(
				float16_t(0.9995),
				float16_t(1.0),
				float16_t(
					float(pcg(seed.x + pcg(seed.y))) / float(0xFFFFFFFFu)
				)
			);

			immut vec3 sun_abs_dist = abs(n_pe - sunDirectionPlr);
			immut bool sun = max3(sun_abs_dist.x, sun_abs_dist.y, sun_abs_dist.z) < 0.04;
			immut bool moon = all(lessThan(abs(n_pe + sunDirectionPlr), fma(skyState.z, 0.0025, 0.02).xxx));

			color = fma(skylight(), f16vec3(moon || sun), fog_col + stars);
		#endif

		imageStore(colorimg1, texel, vec4(color, 0.0));
	}
}
