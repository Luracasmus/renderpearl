#include "/prelude/core.glsl"

/* Sky Rendering */

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

#include "/lib/mv_inv.glsl"
uniform mat4 gbufferProjectionInverse;
uniform layout(rgba16f) restrict writeonly image2D colorimg1;

#include "/lib/mmul.glsl"
#include "/lib/view_size.glsl"
#include "/lib/skylight.glsl"
#include "/lib/srgb.glsl"
#include "/lib/fog.glsl"

#ifndef NETHER
	uniform float frameTimeCounter;

	#include "/lib/prng/pcg.glsl"

	#ifdef END
		#include "/lib/prng/fast_rand.glsl"
	#else
		uniform vec3 sunDirectionPlr;
	#endif
#endif

void main() {
	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);
	immut vec2 texel_size = 1.0 / vec2(view_size());
	immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
	vec3 ndc = fma(vec3(coord, 1.0), vec3(2.0), vec3(-1.0));

	immut vec3 view = proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 pe = MV_INV * view;

	immut f16vec3 n_pe = f16vec3(normalize(pe));

	#ifdef NETHER
		immut f16vec3 fog_col = linear(f16vec3(fogColor));
	#elif defined END
		immut f16vec3 fog_col = sky(n_pe);
	#else
		immut float16_t sky_fog_val = sky_fog(float16_t(n_pe.y));
		immut f16vec3 fog_col = sky(sky_fog_val, n_pe, sunDirectionPlr);

		immut f16vec3 skylight_color = skylight();
	#endif

	vec3 color;

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

		color = stars + fog_col;

		immut vec3 sun_abs_dist = abs(n_pe - sunDirectionPlr);
		immut bool sun = max3(sun_abs_dist.x, sun_abs_dist.y, sun_abs_dist.z) < SUN_SIZE;
		immut bool moon = all(lessThan(abs(n_pe + sunDirectionPlr), fma(skyState.z, MOON_PHASE_DIFF, MOON_SIZE).xxx));

		if (sun || moon) {
			color += skylight_color;
		}
	#endif

	imageStore(colorimg1, texel, vec4(color, 0.0));
}
