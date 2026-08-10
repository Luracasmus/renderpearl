#include "/prelude/core.glsl"

/* Sky Rendering */

layout(local_size_x = 8, local_size_y = 16, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

#include "/lib/mv_inv.glsl"
uniform int packedView;
uniform mat4 gbufferProjectionInverse;
uniform layout(rgba16f) writeonly restrict image2D colorimg1;

#ifdef END
	uniform float endFlashIntensity;
#endif

#include "/lib/mmul.glsl"
#include "/lib/luminance.glsl"
#include "/lib/skylight.glsl"
#include "/lib/srgb.glsl"

#ifndef NETHER
	uniform float frameTimeCounter;

	#include "/lib/prng/pcg.glsl"

	#ifdef END
		#include "/lib/prng/fast_rand.glsl"
	#else
		uniform vec3 sunDirectionPlr;
	#endif
#endif

#include "/lib/fog.glsl"

void main() {
	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);

	#ifdef NETHER
		immut f16vec3 color = linear(f16vec3(fogColor));
	#else
		immut vec2 texel_size = 1.0 / vec2(unpackUint2x16(uint(packedView)));
		immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
		immut vec3 ndc = vec3(fma(coord, vec2(2.0), vec2(-1.0)), 1.0);
		immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
		immut vec3 pe = MV_INV * view;
		immut vec3 n_pe = normalize(pe);

		#ifdef END
			immut f16vec3 color = sky(n_pe);
		#else
			immut f16vec3 sky_light_color = skylight();

			immut float16_t sky_fog_val = sky_fog(float16_t(n_pe.y));
			immut f16vec3 fog_color = sky(sky_fog_val, n_pe, sunDirectionPlr);

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

			f16vec3 color = stars + fog_color;

			immut vec3 sun_abs_dist = abs(n_pe - sunDirectionPlr);
			immut bool sun = max3(sun_abs_dist.x, sun_abs_dist.y, sun_abs_dist.z) < SUN_SIZE;
			immut bool moon = all(lessThan(abs(n_pe + sunDirectionPlr), fma(skyState.z, MOON_PHASE_DIFF, MOON_SIZE).xxx));

			if (sun || moon) {
				color += sky_light_color;
			}
		#endif
	#endif

	imageStore(colorimg1, texel, vec4(color, 0.0));
}
