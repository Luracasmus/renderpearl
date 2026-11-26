#include "/prelude/core.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out IO_F16VEC3 final;
layout(depth_unchanged) out float gl_FragDepth;

#include "/lib/srgb.glsl"

#ifdef FFX_CAS
	#ifdef SMAA
		#define CAS_SAMPLER tempColorLinearS
	#else
		#define CAS_SAMPLER colortex0
	#endif

	uniform sampler2D CAS_SAMPLER;

	#include "/lib/post/ffx_cas.glsl"
#elif defined SMAA
	uniform sampler2D colortex0;
	#include "/lib/post/smaa_nbh_blend.glsl"
#else
	uniform sampler2D tempColorSrgbS;
#endif

void main() {
	immut i16vec2 texel = i16vec2(gl_FragCoord.xy);

	final = (
		#ifdef FFX_CAS
			srgb(ffx_cas(CAS_SAMPLER, texel))
		#elif defined SMAA
			// This is done in `composite3` instead if CAS is also enabled.
			srgb(smaa_nbh_blend(colortex0, texel))
		#else
			f16vec3(texelFetch(tempColorSrgbS, texel, 0).rgb)
		#endif
	);
}
