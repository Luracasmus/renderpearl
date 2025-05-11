#include "/prelude/core.glsl"

out gl_PerVertex {
	vec4 gl_Position;
};

#ifdef ENTITY_SHADOWS
#endif
#ifdef PLAYER_SHADOWS
#endif
#ifdef BLOCK_ENTITY_SHADOWS
#endif

uniform mat4 modelViewMatrix;

#ifdef TERRAIN
	uniform vec3 chunkOffset;

	#if WAVES && defined MAYBE_FLUID
		in vec2 mc_Entity;

		#include "/lib/waves/offset.glsl"
	#endif
#endif

in vec3 vaPosition;

#ifdef TEXTURED
	uniform mat4 textureMatrix;

	in vec2 vaUV0;

	out VertexData { layout(location = 0) noperspective vec2 coord; } v;
#endif

#include "/lib/mmul.glsl"
#include "/lib/sm/distort.glsl"

void main() {
	vec3 model = vaPosition;

	#ifdef TERRAIN
		model += chunkOffset;

		#if WAVES && defined MAYBE_FLUID
			if (mc_Entity.y == 1.0) model.y += wave(model.xz);
		#endif
	#endif

	// modelViewMatrix can be cut to a mat3 since shadowIntervalSize == 0.0 // as long as model -> view conversion only needs rotation
	immut vec3 clip = shadow_proj_scale * (mat3(modelViewMatrix) * model);
	gl_Position = vec4(distort(clip.xy), clip.z, 1.0);
	// RDNA4 ISA documentation states .w is optional, but the fallback value doesn't seem to be 1.0 on AMD drivers, so we write to it anyways

	#ifdef TEXTURED
		v.coord = rot_trans_mmul(textureMatrix, vaUV0);
	#endif
}