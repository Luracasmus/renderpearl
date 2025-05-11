#include "/prelude/core.glsl"

#ifdef TRANSLUCENT // requires TINTED
	/* RENDERTARGETS: 1 */
	layout(location = 0) out vec4 colortex1;
#else
	/* RENDERTARGETS: 1,2 */
	layout(location = 0) out vec3 colortex1;
	layout(location = 1) out uvec2 colortex2;
#endif

layout(depth_unchanged) out float gl_FragDepth;

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
				colortex1 = unpack_un11_11_10(v.tint) * f16vec3(texture(gtexture, v.coord));
				colortex2.g = 0x40000000u;
			#endif
		#else
			colortex1 = f16vec3(texture(gtexture, v.coord));
			colortex2.g = 0x40000000u;
		#endif
	#else // has to be TINTED
		#ifdef TRANSLUCENT
			colortex1 = unpackUnorm4x8(v.tint);
		#else
			colortex1 = unpack_un11_11_10(v.tint);
			colortex2.g = 0x40000000u; // set light and emission to 0 and "pure light" flag to 1
		#endif
	#endif
}
