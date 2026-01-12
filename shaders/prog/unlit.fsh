#include "/prelude/core.glsl"

#ifdef TRANSLUCENT // Requires `TINTED`
	/* RENDERTARGETS: 1 */
	layout(location = 0) out f16vec4 colortex1;
#else
	/* RENDERTARGETS: 1 */

	layout(location = 0) out f16vec3 colortex1;

	#ifdef ALPHA_CHECK
		layout(depth_greater) out float gl_FragDepth;

		uniform float alphaTestRef;
	#else
		layout(depth_unchanged) out float gl_FragDepth;
	#endif
#endif

uniform sampler2D gtexture;

in VertexData {
	#ifdef TINTED
		layout(location = 0, component = 0) flat uint tint;
	#endif

	#ifdef TEXTURED
		layout(location = 1, component = 0) vec2 coord;
	#endif
} v;

#include "/lib/srgb.glsl"

#if defined TINTED && !defined TRANSLUCENT
	#include "/lib/un11_11_10.glsl"
#endif

void main() {
	#ifdef TEXTURED
		#ifdef TINTED
			#ifdef TRANSLUCENT
				immut f16vec4 color = f16vec4(texture(gtexture, v.coord));
				colortex1 = f16vec4(unpackUnorm4x8(v.tint)) * f16vec4(linear(color.rgb), color.a);
			#else
				#ifdef ALPHA_CHECK
					immut f16vec4 color = f16vec4(texture(gtexture, v.coord));
					if (color.a < float16_t(alphaTestRef)) discard;
				#else
					immut f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);
				#endif

				colortex1 = unpack_un11_11_10(v.tint) * linear(color.rgb);
			#endif
		#else
			/* // Currently unused.
				#ifdef ALPHA_CHECK
					immut f16vec4 color = f16vec4(texture(gtexture, v.coord));
					if (color.a < float16_t(alphaTestRef)) discard;
				#else
					immut f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);
				#endif
			*/
			immut f16vec3 color = f16vec3(texture(gtexture, v.coord).rgb);

			colortex1 = linear(color.rgb);
		#endif
	#else // Has to be `TINTED`.
		#ifdef TRANSLUCENT
			colortex1 = f16vec4(unpackUnorm4x8(v.tint));
		#else
			colortex1 = unpack_un11_11_10(v.tint);
		#endif
	#endif
}
