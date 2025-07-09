#include "/prelude/core.glsl"

#ifdef IS_OCULUS
	#error "RenderPearl: RenderPearl requires Iris, but seems to have been loaded by Oculus instead, which may not be fully compatible. No support will be provided for using RenderPearl in this configuration."
#elif !defined IS_IRIS
	#error "RenderPearl: RenderPearl requires Iris, but seems to have been loaded by a different, unknown shader loader. Various issues may occur. No support will be provided for using RenderPearl in this configuration."
#endif

#ifdef IS_MONOCLE
	#error "RenderPearl: The Monocle mod is incompatible with RenderPearl. Visual issues may occur. No support will be provided for using RenderPearl in this configuration."
#endif

#ifdef DISTANT_HORIZONS
	#error "RenderPearl: RenderPearl does not render Distant Horizons geometry. For optimal performance, please disable "Enable Rendering" in your Distant Horizons configuration."
#endif

#ifdef CHUNKS_FADE_IN_ENABLED
	#error "RenderPearl: Chunks Fade In support is experimental. Various issues may occur."
#endif

const ivec3 workGroups = ivec3(1, 1, 1);
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

writeonly
#include "/buf/indirect/dispatch.glsl"

writeonly
#include "/buf/ll.glsl"

#if AUTO_EXP
	writeonly
	#include "/buf/auto_exp.glsl"
#endif

#if HAND_LIGHT
	writeonly
	#include "/buf/hand_light.glsl"
#endif

void main() {
	indirect_dispatch.work_groups = uvec3(0u, 1u, 1u);

	#if AUTO_EXP
		auto_exp.sum_log_luma = 0;
		auto_exp.exposure = float16_t(1.0);
	#endif

	ll.queue = 0u;
	ll.len = uint16_t(0u);

	#if HAND_LIGHT
		hand_light.data = uvec4(0u);
	#endif
}
