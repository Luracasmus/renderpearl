#include "/prelude/core_compatibility.glsl"

out gl_PerVertex { vec4 gl_Position; };

in vec3 vaPosition;

#include "/lib/mmul.glsl"
#include "/lib/sm/distort.glsl"

void main() {
	vec3 model = vec3(gl_Vertex);

	// `modelViewMatrix` can be cut to a `mat3` since `shadowIntervalSize == 0.0`, as long as model -> view conversion only needs rotation and/or scale, which seems to always be the case in Iris.
	immut vec3 clip = shadow_proj_scale.xxy * (mat3(gl_ModelViewMatrix) * model);
	gl_Position = vec4(clip.xy * distortion(clip.xy), clip.z, 1.0);
	// RDNA4 ISA documentation states `.w` is optional, but the fallback value doesn't seem to be `1.0` on AMD drivers, so we write to it anyways.
}
