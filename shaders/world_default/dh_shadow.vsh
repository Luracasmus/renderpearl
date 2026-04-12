#include "/prelude/config.glsl"

#if SM_DIST == 0 || defined END || defined NETHER
	#include "/prog/none.vsh"
#else
	#version 460 compatibility

	#include "/prelude/compat.glsl"
	#include "/prelude/directive.glsl"
	#include "/prelude/lib.glsl"

	out gl_PerVertex { vec4 gl_Position; };

	uniform mat4 dhProjection;
	uniform int dhRenderDistance;

	#include "/lib/mmul.glsl"
	#include "/lib/sm/distort.glsl"

	void main() {
		vec3 model = vec3(gl_Vertex);

		// `gl_ModelViewMatrix` can be cut to a `mat3` since `shadowIntervalSize == 0.0`, as long as model -> view conversion only needs rotation and/or scale, which seems to always be the case in Iris.
		immut vec3 clip = shadow_proj_scale.xxy * (mat3(gl_ModelViewMatrix) * model); // vec3(dhProjection[0].x, dhProjection[1].y, dhProjection[2].z) *
		gl_Position = vec4(clip.xy * distortion(clip.xy), clip.z, 1.0);
		// RDNA4 ISA documentation states `.w` is optional, but the fallback value doesn't seem to be `1.0` on AMD drivers, so we write to it anyways.
	}
#endif
