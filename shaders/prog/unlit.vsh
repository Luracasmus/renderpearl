#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };

uniform mat4 modelViewMatrix, projectionMatrix;

#ifdef HAS_MODEL_OFFSET
	uniform vec3 chunkOffset;
#endif

in vec3 vaPosition;

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
	in vec4 vaColor;

	#include "/lib/srgb.glsl"

	#ifndef TRANSLUCENT
		#include "/lib/un11_11_10.glsl"
	#endif
#endif

#ifdef TEXTURED
	uniform mat4 textureMatrix;
	in vec2 vaUV0;
#endif

void main() {
	#ifdef DISCARD_TRANSLUCENT
		if (vaColor.a < 1.0) {
			gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
		} else
	#endif
	{
		vec3 model = vaPosition;

		#ifdef HAS_MODEL_OFFSET
			model += chunkOffset;
		#endif

		gl_Position = proj_mmul(projectionMatrix, rot_trans_mmul(modelViewMatrix, model));

		#ifdef TEXTURED
			v.coord = rot_trans_mmul(textureMatrix, vaUV0);
		#endif

		#ifdef TINTED
			#ifdef TRANSLUCENT
				immut vec4 color = vaColor;
				v.tint = packUnorm4x8(vec4(linear(color.rgb), color.a));
			#else
				v.tint = pack_un11_11_10(linear(vaColor.rgb));
			#endif
		#endif
	}
}
