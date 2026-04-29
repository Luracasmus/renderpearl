#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };

#ifdef CLRWL
	#define TEXTURED
#endif

out VertexData {
	#ifdef TINTED
		layout(location = 0, component = 0) flat uint tint;
	#endif

	#ifdef TEXTURED
		layout(location = 1, component = 0) vec2 coord;
	#endif
} v;

#include "/lib/mmul.glsl"

#ifdef TINTED
	#include "/lib/srgb.glsl"

	#ifndef TRANSLUCENT
		#include "/lib/un11_11_10.glsl"
	#endif
#endif

void main() {
	immut vec4 color = vec4(gl_Color);

	#ifdef DISCARD_TRANSLUCENT
		if (color.a < 1.0) {
			gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
		} else
	#endif
	{
		vec3 model = vec3(gl_Vertex);

		gl_Position = proj_mmul(mat4(gl_ProjectionMatrix), rot_trans_mmul(mat4(gl_ModelViewMatrix), model));

		#ifdef TEXTURED
			v.coord = rot_trans_mmul(mat4(gl_TextureMatrix[0]), vec2(gl_MultiTexCoord0));
		#endif

		#ifdef TINTED
			#ifdef TRANSLUCENT
				v.tint = packUnorm4x8(vec4(linear(color.rgb), color.a));
			#else
				v.tint = pack_un11_11_10(linear(color.rgb));
			#endif
		#endif
	}
}
