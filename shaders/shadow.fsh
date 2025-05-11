#include "/prelude/core.glsl"

/* RENDERTARGETS: 0 */

#ifdef TEXTURED
	uniform sampler2D gtexture;

	in VertexData { layout(location = 0) noperspective vec2 coord; } v;

	#ifdef TRANSLUCENT
		layout(location = 0) out vec3 shadowcolor0;
		layout(depth_unchanged) out float gl_FragDepth;

		uniform sampler2D shadowtex1;

		#include "/lib/srgb.glsl"
	#else
		layout(depth_greater) out float gl_FragDepth;

		uniform float alphaTestRef;
	#endif
#else
	layout(depth_unchanged) out float gl_FragDepth;
#endif

void main() {
	#ifdef TEXTURED
		#ifdef TRANSLUCENT
			f16vec4 color = f16vec4(texture(gtexture, v.coord));

			// Beer–Lambert law https://discord.com/channels/237199950235041794/276979724922781697/612009520117448764
			// todo!() make this configurable
			immut float16_t falloff = float16_t(1.0) - exp(float16_t(-75.0) * (
				float16_t(texelFetch(shadowtex1, ivec2(gl_FragCoord.xy), 0).r) - float16_t(gl_FragCoord.z)
			));
			color.a += falloff;

			color.rgb = linear(color.rgb);
			color.rgb *= float16_t(1.0) - max(float16_t(0.0), color.a - float16_t(1.0));

			shadowcolor0 = mix(f16vec3(1.0), color.rgb, min(color.a, float16_t(1.0)));
		#else
			if (texture(gtexture, v.coord).a < alphaTestRef) discard;
		#endif
	#endif
}