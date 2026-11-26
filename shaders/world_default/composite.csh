#include "/prelude/core.glsl"

#if (VL != 0 && defined SM_ACTIVE) || defined SMAA || defined FFX_CAS
	layout(local_size_x = 8, local_size_y = 16, local_size_z = 1) in; // Keep synced with composite2_a.csh `composite_wg_size`.
	const vec2 workGroupsRender = vec2(1.0, 1.0);

	#if defined SMAA || defined FFX_CAS
		uniform layout(rgba16f) restrict image2D colorimg0;
	#else
		uniform layout(rgba16f) restrict readonly image2D colorimg0;
		uniform layout(rgba8) restrict writeonly image2D tempColorSrgb;
	#endif

	#if (VL != 0 && defined SM_ACTIVE) || defined COMPASS
		uniform int packedView;
	#endif

	#if (VL != 0 && defined SM_ACTIVE) || !(defined SMAA || defined FFX_CAS)
		#include "/lib/srgb.glsl"
	#endif

	#include "/lib/post/color.glsl"

	#if VL != 0 && defined SM_ACTIVE
		#include "/lib/mv_inv.glsl"
		uniform float pbrFogDensity;
		uniform vec3 sunDirectionPlr;
		uniform mat4 gbufferProjectionInverse, shadowModelView;
		uniform sampler2D depthtex0;

		#ifdef END
			uniform float endFlashIntensity;
		#endif

		float16_t pbr_fog(float dist) {
			// Beer–Lambert law https://discord.com/channels/237199950235041794/276979724922781697/612009520117448764
			return min(float16_t(1.0 - exp(-0.001 / pbrFogDensity * dist)), float16_t(1.0));
		}

		#ifdef END
			#include "/lib/prng/pcg.glsl"
			uniform float frameTimeCounter;
		#endif

		#ifdef VOXY
			uniform int vxRenderDistance;
		#elif defined DISTANT_HORIZONS
			uniform int dhRenderDistance;
		#else
			uniform float far;
		#endif

		#include "/lib/mmul.glsl"
		#include "/lib/skylight.glsl"
		#include "/lib/sm/sample.glsl"
		#include "/lib/sm/distort.glsl"
		#include "/lib/prng/ign.glsl"
		#include "/lib/fog.glsl"

		shared struct {
			uint16_t[gl_WorkGroupSize.x + 2][gl_WorkGroupSize.y + 2] nbh;
		} sh;

		// Compute and return volumetric light value and add it to the shared neighborhood.
		f16vec3 volumetric_light(bool is_geo, float depth, i16vec2 texel, vec2 texel_size, uvec2 nbh_pos, out vec3 pe) {
			f16vec3 ray = f16vec3(0.0);

			if (is_geo) {
				immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);
				immut vec3 ndc = fma(vec3(coord, depth), vec3(2.0), vec3(-1.0));
				pe = MV_INV * proj_inv(gbufferProjectionInverse, ndc);
				immut float pe_dist = length(pe);
				immut vec3 pf = pe + mvInv3;

				immut vec3 view_zero = proj_inv(gbufferProjectionInverse, ndc.xy);
				immut vec3 pf_zero = MV_INV * view_zero + mvInv3;

				// immut float16_t density = float16_t(-0.02) * float16_t(fogState.y);

				for (uint i = 0u; i < uint(VL_SAMPLES); i++) {
					immut float dist = ign(vec2(texel), float(frameCounter + i)); // pow(..., 1.5) ?
					immut vec3 sample_pf = mix(pf_zero, pf, dist);

					immut vec3 sample_s_ndc = shadow_proj_scale.xxy * rot_trans_mmul(shadowModelView, sample_pf);
					immut vec3 s_scrn = fma(vec3(sample_s_ndc.xy * distortion(sample_s_ndc.xy), sample_s_ndc.z), vec3(0.5), vec3(0.5));

					ray += sample_sm(float16_t(1.0) - float16_t(exp(-0.1 / pbrFogDensity * pe_dist * dist)), s_scrn);
				}

				immut uvec3 scaled_ray = uvec3(fma(ray, f16vec3(31.0, 63.0, 31.0), f16vec3(0.5)));
				sh.nbh[nbh_pos.x][nbh_pos.y] = uint16_t(bitfieldInsert(bitfieldInsert(scaled_ray.r, scaled_ray.g, 5, 6), scaled_ray.b, 11, 5));
			} else {
				sh.nbh[nbh_pos.x][nbh_pos.y] = uint16_t(0u);
			}

			return ray;
		}

		void add_nbh_ray(inout f16vec3 accum_ray, uvec2 nbh_pos) {
			immut uint16_t packed_ray = sh.nbh[nbh_pos.x][nbh_pos.y];

			accum_ray = fma(f16vec3(
				packed_ray & uint16_t(31u),
				bitfieldExtract(uint(packed_ray), 5, 6),
				packed_ray >> uint16_t(11u)
			), f16vec3(1.0 / vec3(31.0, 63.0, 31.0)), accum_ray);
		}
	#endif

	void main() {
		immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);
		f16vec3 color = f16vec3(imageLoad(colorimg0, texel).rgb);

		#if VL != 0 && defined SM_ACTIVE
			immut float depth = texelFetch(depthtex0, texel, 0).r;
			immut vec2 texel_size = 1.0 / vec2(unpackUint2x16(uint(packedView)));
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
				immut float16_t render_dist = float16_t(
					#ifdef VOXY
						float16_t(16.0) * float16_t(vxRenderDistance)
					#elif defined DISTANT_HORIZONS
						dhRenderDistance
					#else
						far
					#endif
				);
				immut float16_t fog = saturate(vanilla_fog(pe, render_dist) + pbr_fog(length(pe)));

				// We use the average VL color of a 3x3 neighborhood of invocations
				// to take advantage of IGN's low discrepancy
				// and get reasonably good results with very few samples.

				// Remember that our current ray is at (+1, +1) offset. We add all the other ones here.
				add_nbh_ray(ray, gl_LocalInvocationID.xy);
				add_nbh_ray(ray, uvec2(gl_LocalInvocationID.x, gl_LocalInvocationID.y + 1u));
				add_nbh_ray(ray, uvec2(gl_LocalInvocationID.x, gl_LocalInvocationID.y + 2u));

				add_nbh_ray(ray, uvec2(gl_LocalInvocationID.x + 1u, gl_LocalInvocationID.y));
				add_nbh_ray(ray, gl_LocalInvocationID.xy + uvec2(1u, 2u));

				add_nbh_ray(ray, uvec2(gl_LocalInvocationID.x + 2u, gl_LocalInvocationID.y));
				add_nbh_ray(ray, gl_LocalInvocationID.xy + uvec2(2u, 1u));
				add_nbh_ray(ray, gl_LocalInvocationID.xy + 2u);

				ray *= float16_t(float(VL) * 0.001 / float(9u * uint(VL_SAMPLES))) * (float16_t(1.0) - fog);
				color = fma(ray, skylight(), color);
			}
		#endif

		color = process_color(color, texel);

		#if defined SMAA || defined FFX_CAS
			imageStore(colorimg0, texel, f16vec4(color, 0.0));
		#else
			imageStore(tempColorSrgb, texel, f16vec4(srgb(color), 0.0));
		#endif
	}
#else
	// Color processing is done in `final` instead.
	layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
	const ivec3 workGroups = ivec3(0, 0, 0);

	void main() {}
#endif
