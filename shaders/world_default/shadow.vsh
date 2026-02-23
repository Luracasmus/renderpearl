#include "/prelude/core.glsl"

out gl_PerVertex { vec4 gl_Position; };

#ifdef SM_ENTITY
#endif
#ifdef SM_PLR
#endif
#ifdef SM_BLOCK_ENTITY
#endif

#ifdef TERRAIN
	#if WAVES && defined MAYBE_FLUID
		in vec2 mc_Entity;

		#include "/lib/waves/offset.glsl"
	#endif
#endif

#ifdef TEXTURED
	out VertexData { layout(location = 0) noperspective vec2 coord; } v;
#endif

#include "/lib/mmul.glsl"
#include "/lib/sm/distort.glsl"

void main() {
	vec3 model = vec3(gl_Vertex);

	#ifdef TERRAIN
		#if WAVES && defined MAYBE_FLUID
			if (mc_Entity.y == 1.0) model.y += wave(model.xz);
		#endif
	#endif

	// `gl_ModelViewMatrix` can be cut to a `mat3` since `shadowIntervalSize == 0.0`, as long as model -> view conversion only needs rotation and/or scale, which seems to always be the case in Iris.
	immut vec3 clip = shadow_proj_scale.xxy * (mat3(gl_ModelViewMatrix) * model);
	gl_Position = vec4(clip.xy * distortion(clip.xy), clip.z, 1.0);
	// RDNA4 ISA documentation states `.w` is optional, but the fallback value doesn't seem to be `1.0` on AMD drivers, so we write to it anyways.

	#ifdef TEXTURED
		v.coord = rot_trans_mmul(mat4(gl_TextureMatrix[0]), vec2(gl_MultiTexCoord0));
	#endif
}
