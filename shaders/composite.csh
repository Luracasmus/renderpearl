#include "/prelude/core.glsl"

layout(local_size_x = 8, local_size_y = 16, local_size_z = 1) in; // Keep synced with composite2_a.csh `composite_wg_size`.
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform layout(rgba16f) restrict image2D colorimg1;

#if AUTO_EXP
	#include "/buf/auto_exp.glsl"
#endif

#ifdef COMPASS
	uniform vec3 playerLookVector;
#endif

#if defined COMPASS || (defined VL && !defined NETHER)
	#include "/lib/view_size.glsl"
#endif

#include "/lib/tonemap.glsl"

#if VL && !defined NETHER
	#include "/lib/mv_inv.glsl"
	uniform float pbrFogDensity;
	uniform vec3 sunDirectionPlr;
	uniform mat4 gbufferProjectionInverse, shadowModelView;
	uniform sampler2D depthtex0;

	float16_t pbr_fog(float dist) {
		// Beer–Lambert law https://discord.com/channels/237199950235041794/276979724922781697/612009520117448764
		return min(float16_t(1.0 - exp(-0.001 / pbrFogDensity * dist)), float16_t(1.0));
	}

	#ifdef END
		#include "/lib/prng/fast_rand.glsl"
		uniform float frameTimeCounter;
	#endif

	#include "/lib/mmul.glsl"
	#include "/lib/srgb.glsl"
	#include "/lib/skylight.glsl"
	#include "/lib/fog.glsl"
	#include "/lib/sm/sample.glsl"
	#include "/lib/sm/distort.glsl"
	#include "/lib/prng/ign.glsl"

	struct Shared {
		uint16_t[gl_WorkGroupSize.x + 2][gl_WorkGroupSize.y + 2] nbh;
	}; shared Shared sh;

	// Compute and return volumetric light value and add it to the shared neighborhood.
	f16vec3 volumetric_light(bool is_geo, float depth, i16vec2 texel, vec2 texel_size, uvec2 nbh_pos, out vec3 pe) {
		f16vec3 ray = f16vec3(0.0);

		if (is_geo) {
			immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
			immut vec3 ndc = fma(vec3(coord, depth), vec3(2.0), vec3(-1.0));
			pe = MV_INV * proj_inv(gbufferProjectionInverse, ndc);
			immut float pe_dist = length(pe);

			immut vec4 view_undiv_zero = gbufferProjectionInverse * vec4(ndc.xy, 0.0, 1.0);
			immut vec3 view_zero = view_undiv_zero.xyz / view_undiv_zero.w;
			immut vec3 pe_zero = MV_INV * view_zero;

			// immut float16_t density = float16_t(-0.02) * float16_t(fogState.y);

			for (uint i = 0u; i < uint(VL_SAMPLES); ++i) {
				immut float dist = ign(vec2(texel), float(frameCounter + i)); // pow(..., 1.5) ?
				immut vec3 sample_pe = mix(pe_zero, pe, dist);

				immut vec3 sample_s_ndc = shadow_proj_scale * (mat3(shadowModelView) * (sample_pe + mvInv3));
				immut vec3 s_scrn = fma(vec3(distort(sample_s_ndc.xy), sample_s_ndc.z), vec3(0.5), vec3(0.5));

				ray += sample_sm(float16_t(1.0) - float16_t(exp(-0.1 / pbrFogDensity * pe_dist * dist)), s_scrn);
			}

			immut uvec3 scaled_ray = uvec3(fma(ray, f16vec3(31.0, 63.0, 31.0), f16vec3(0.5)));
			sh.nbh[nbh_pos.x][nbh_pos.y] = uint16_t(bitfieldInsert(bitfieldInsert(scaled_ray.r, scaled_ray.g, 5, 6), scaled_ray.b, 11, 5));
		} else {
			sh.nbh[nbh_pos.x][nbh_pos.y] = uint16_t(0u);
		}

		return ray;
	}
#endif

void main() {
	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);
	f16vec3 color = f16vec3(imageLoad(colorimg1, texel).rgb);

	#if VL && !defined NETHER
		immut float depth = texelFetch(depthtex0, texel, 0).r;
		immut vec2 texel_size = 1.0 / vec2(view_size());
		immut bool is_geo = depth < 1.0;

		immut uvec2 nbh_pos = gl_LocalInvocationID.xy + 1u;
		vec3 pe; f16vec3 ray = volumetric_light(is_geo, depth, texel, texel_size, nbh_pos, pe);

		i16vec2 border_offset;
		bool is_border;
		#define BORDER_OP(offset) { border_offset = i16vec2(offset); is_border = true; }
		#define NON_BORDER_OP { is_border = false; }
		#include "/lib/nbh/border_cornered.glsl"

		if (is_border) {
			immut i16vec2 border_texel = texel + i16vec2(border_offset);
			immut float border_depth = texelFetch(depthtex0, border_texel, 0).r;

			vec3 _border_pe;

			volumetric_light(
				border_depth < 1.0,
				border_depth,
				border_texel,
				texel_size,
				uvec2(ivec2(nbh_pos) + ivec2(border_offset)),
				_border_pe
			);
		}

		barrier();

		if (is_geo) { // Apply computed volumetric light.
			immut float16_t fog = saturate(vanilla_fog(pe) + pbr_fog(length(pe)));

			// We use the average VL color of a 3x3 neighborhood of invocations
			// to take advantage of IGN's low discrepancy
			// and get reasonably good results with very few samples.
			const uvec2[8] offsets = uvec2[8](
				uvec2(0u, 0u), uvec2(1u, 0u), uvec2(2u, 0u), uvec2(2u, 1u), uvec2(2u, 2u), uvec2(1u, 2u), uvec2(0u, 2u), uvec2(0u, 1u)
			);

			for (uint i = 0u; i < offsets.length(); ++i) {
				immut uvec2 nbh_pos = gl_LocalInvocationID.xy + offsets[i];
				immut uint16_t packed_ray = sh.nbh[nbh_pos.x][nbh_pos.y];

				ray = fma(f16vec3(
					packed_ray & uint16_t(31u),
					bitfieldExtract(uint(packed_ray), 5, 6),
					packed_ray >> uint16_t(11u)
				), f16vec3(1.0 / vec3(31.0, 63.0, 31.0)), ray);
			}

			ray *= float16_t(float(VL) * 0.001 / float((offsets.length() + 1u) * uint(VL_SAMPLES))) * (float16_t(1.0) - fog);
			color = fma(ray, skylight(), color);
		}
	#endif

	/*
		vec2 coord = fma(vec2(texel), 2.0 / vec2(view_size()), vec2(-1.0));

		const float markiplier = 0.1;

		coord *= fma(length(coord), markiplier, 1.0 - markiplier);
		immut vec2 abs_coord = abs(coord);
		coord *= fma(max(abs_coord.x, abs_coord.y), markiplier, 1.0 - markiplier);

		coord = fma(mix(coord, mod(fma(coord, vec2(0.5), vec2(0.5)), 0.25), 0.5), vec2(0.5), vec2(0.5));
		i16vec2 distorted_texel = i16vec2(fma(coord, vec2(view_size()), vec2(0.5)));
	*/

	#if RED_MUL != 100 || GREEN_MUL != 100 || BLUE_MUL != 100
		color *= f16vec3(0.01 * vec3(RED_MUL, GREEN_MUL, BLUE_MUL));
		// TODO: Fix negative muls so that they actually invert the color.
	#endif

	#if SATURATION != 100 || AUTO_EXP
		immut float16_t luma = luminance(color);
	#endif

	#if SATURATION != 100
		color = mix(luma.rrr, color, float16_t(SATURATION * 0.01));
	#endif

	#if AUTO_EXP
		if (gl_LocalInvocationIndex == 0u) {
			// Clamp to avoid over- or underflowing the counter.
			atomicAdd(auto_exp.sum_log_luma, int(roundEven(clamp(log2(luma), float16_t(-7.0), float16_t(7.0)) * float16_t(512.0))));
		}

		color *= auto_exp.exposure;
	#endif

	#ifdef COMPASS
		immut vec2 coord = (vec2(texel) + 0.5) / vec2(view_size());

		const vec2 comp_pos = vec2(0.5, 0.9);
		const vec2 comp_size = vec2(0.1, 0.01);
		const float comp_line = 0.01;

		immut vec2 comp_dist = (coord - comp_pos) / comp_size;
		immut vec2 abs_dist = abs(comp_dist);

		if (max(abs_dist.x, abs_dist.y) < 1.0) {
			const float inv_comp_line = 1.0 - comp_line;

			immut float ang = PI * -0.5 * comp_dist.x;
			immut float s = sin(ang);
			immut float c = cos(ang);
			immut vec2 dir = mat2(c, -s, s, c) * normalize(playerLookVector.xz);

			vec3 comp_color = vec3(0.0);

			/*
				W - < x > + E
				N - < z > + S
			*/

			comp_color.r += saturate(-dir.y - inv_comp_line);
			comp_color.rg += saturate(dir.x - inv_comp_line);
			comp_color.rb += saturate(-dir.x - inv_comp_line);
			comp_color.gb += saturate(dir.y - inv_comp_line);

			comp_color = fma(comp_color, (1.0 / comp_line).xxx, vec3(max(0.1 - abs_dist.y, 0.0) * 10.0));

			color = f16vec3(mix(color, comp_color, luminance(comp_color) * step(0.0, 1.5 - abs_dist.x - abs_dist.y))); // TODO: Make actually float16_t.
		}
	#endif

	imageStore(colorimg1, texel, f16vec4(tonemap(color), 0.0));
}
