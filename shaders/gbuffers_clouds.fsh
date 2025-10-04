#include "/prelude/core.glsl"

/* RENDERTARGETS: 1 */
layout(location = 0) out f16vec4 colortex1;
layout(depth_unchanged) out float gl_FragDepth;

uniform float frameTimeCounter;
uniform vec3 cameraPosition, sunDirectionPlr;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;

in VertexData { layout(location = 0, component = 0) flat uint tint; } v;

#include "/lib/view_size.glsl"
#include "/lib/mmul.glsl"
#include "/lib/un11_11_10.glsl"
#include "/lib/srgb.glsl"
#include "/lib/skylight.glsl"
#include "/lib/fog.glsl"
#include "/lib/prng/pcg.glsl"

void main() {
	immut vec3 ndc = fma(vec3(gl_FragCoord.xy / view_size(), gl_FragCoord.z), vec3(2.0), vec3(-1.0));
	immut vec3 pe = mat3(gbufferModelViewInverse) * proj_inv(gbufferProjectionInverse, ndc);
	immut vec3 world = pe + gbufferModelViewInverse[3].xyz + cameraPosition;

	immut vec2 abs_pe = abs(pe.xz);
	immut float16_t fog = min(float16_t(pow(max(abs_pe.x, abs_pe.y) / float(16 * CLOUD_FOG_END), fogState.y)), float16_t(1.0));

	immut float16_t dist = length(f16vec3(pe));

	immut vec3 n_pe = normalize(pe);
	immut f16vec3 fog_col = sky(sky_fog(float16_t(n_pe.y)), n_pe, sunDirectionPlr);

	immut vec2 scaled_world_xz = fma(world.xz, vec2(1.0/64.0), vec2(0.25 * frameTimeCounter));
	immut ivec2 int_scaled_world_xz = ivec2(scaled_world_xz);

	immut ivec2 offset = mix(ivec2(-1), ivec2(1), greaterThanEqual(scaled_world_xz, vec2(0.0)));

	immut uvec2[4] quant_pe = uvec2[4](
		uvec2(int_scaled_world_xz),
		uvec2(int_scaled_world_xz.x + offset.x, int_scaled_world_xz.y),
		uvec2(int_scaled_world_xz.x, int_scaled_world_xz.y + offset.y),
		uvec2(int_scaled_world_xz + offset)
	);

	immut uvec4 noise = uvec4(
		pcg(quant_pe[0].x + pcg(quant_pe[0].y)),
		pcg(quant_pe[1].x + pcg(quant_pe[1].y)),
		pcg(quant_pe[2].x + pcg(quant_pe[2].y)),
		pcg(quant_pe[3].x + pcg(quant_pe[3].y))
	);

	immut f16vec4 norm_noise = mix(
		f16vec4(vec4(noise) / float(0xFFFFFFFFu)),
		f16vec4(1.0),
		float16_t(0.5)
	);

	immut f16vec2 fract_scaled_world_xz = f16vec2(fract(abs(scaled_world_xz)));
	immut float16_t alpha = mix(
		mix(norm_noise.x, norm_noise.y, fract_scaled_world_xz.x),
		mix(norm_noise.z, norm_noise.w, fract_scaled_world_xz.x),
		fract_scaled_world_xz.y
	);

	immut f16vec3 color = float16_t(0.25) * skylight() + float16_t(0.5) * unpack_un11_11_10(v.tint);

	colortex1 = f16vec4(
		mix(mix(color, fog_col, float16_t(0.25)), fog_col, fog),
		min(dist * float16_t(0.01), float16_t(0.75)) * (float16_t(1.0) - fog) * alpha
	);
}
