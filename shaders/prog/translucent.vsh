#include "/prelude/core.glsl"

out gl_PerVertex {
	vec4 gl_Position;
};

uniform float farSquared;
uniform vec3 shadowLightDirectionPlr;
uniform mat4 gbufferModelViewInverse, modelViewMatrix, projectionMatrix, shadowModelView, textureMatrix;

#ifndef NO_NORMAL
	uniform mat3 normalMatrix;

	#include "/lib/tbn/vsh.glsl"
#endif

#if defined TERRAIN || (!defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP))
	in vec2 mc_midTexCoord;
#endif

#ifdef TERRAIN
	uniform vec3 chunkOffset;

	in vec2 mc_Entity;
	in vec4 at_midBlock;

	#if WAVES
		#include "/lib/waves/offset.glsl"
	#endif
#endif

#ifdef ENTITY_COLOR
	uniform vec4 entityColor;
#endif

#if !defined TERRAIN || !(SM && defined MC_SPECULAR_MAP)
	uniform sampler2D gtexture;
#endif

in vec2 vaUV0;
in vec3 vaPosition;
in vec4 vaColor;

out VertexData {
	layout(location = 2, component = 0) vec3 tint;
	layout(location = 3, component = 0) vec3 light;
	layout(location = 4, component = 0) vec3 view;
	layout(location = 5, component = 0) vec2 coord;

	#ifdef TERRAIN
		layout(location = 1, component = 3) flat float alpha;

		#if !(SM && defined MC_SPECULAR_MAP)
			layout(location = 6, component = 0) flat float avg_luma;
		#endif
	#endif

	#ifndef NETHER
		layout(location = 7, component = 0) vec3 s_screen;
	#endif

	#if !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)
		layout(location = 8, component = 0) flat uint mid_coord;
		layout(location = 8, component = 1) flat uint face_tex_size;
	#endif
} v;

#include "/lib/mmul.glsl"
#include "/lib/sm/bias.glsl"
#include "/lib/vertex_block_light.glsl"
#include "/lib/sm/distort.glsl"

void main() {
	vec3 model = vaPosition;

	#ifdef TERRAIN
		model += chunkOffset;

		if (mc_Entity.y == 1.0) {
			v.alpha = WATER_OPACITY * 0.01;

			#if WAVES
				model.y += wave(model.xz);
			#endif
		} else v.alpha = 1.0;
	#endif

	if (dot(model.xz, model.xz) < farSquared) {
		v.view = rot_trans_mmul(modelViewMatrix, model);
		gl_Position = proj_mmul(projectionMatrix, v.view);

		immut vec3 v_normal =
			#ifdef NO_NORMAL
				vec3(0.0, 0.0, 1.0);
			#else
				normalMatrix * normalize(vaNormal);
			#endif

		#ifndef NO_NORMAL
			tbn_comp.normal = v_normal;
			tbn_comp.tangent = normalMatrix * normalize(at_tangent.xyz);
			tbn_comp.handedness = at_tangent.w;
		#endif

		immut f16vec3 w_normal = f16vec3(mat3(gbufferModelViewInverse) * v_normal);
		v.light = indexed_block_light(mat3(gbufferModelViewInverse) * v.view, w_normal);

		#ifndef NETHER
			immut float16_t n_dot_l = dot(w_normal, f16vec3(shadowLightDirectionPlr));
			vec2 bias = shadow_bias(n_dot_l);

			#if SSS && defined TERRAIN
				// todo!() check that this makes sense
				if (mc_Entity.x == 0.0 && n_dot_l < float16_t(0.0)) bias *= -1.0;
			#endif

			vec3 s_ndc = shadow_proj_scale * (mat3(shadowModelView) * rot_trans_mmul(gbufferModelViewInverse, v.view));
			s_ndc.xy = distort(s_ndc.xy);

			s_ndc = fma(mat3(shadowModelView) * vec3(bias.y * w_normal), shadow_proj_scale, s_ndc);
			//s_ndc.z += float(bias.x); // doesn't really seem to help :/

			v.s_screen = fma(s_ndc, vec3(0.5), vec3(0.5));
		#endif

		#ifdef TERRAIN
			immut float16_t emission = min((max(float16_t(mc_Entity.x), float16_t(0.0)) + float16_t(at_midBlock.w)) / float16_t(15.0), float16_t(1.0));
			v.light.x = min(fma(emission, float16_t(0.3), max(v.light.x, emission)), float16_t(1.0));

			#if !(SM && defined MC_SPECULAR_MAP)
				v.avg_luma = luminance(vaColor.rgb * textureLod(gtexture, mc_midTexCoord, 4.0).rgb);

				if (mc_Entity.y == 1.0) v.avg_luma -= 0.75;
			#endif
		#endif

		v.tint = vaColor.rgb;
		#ifdef ENTITY_COLOR
			v.tint = mix(v.tint, entityColor.rgb, entityColor.a);
		#endif

		v.coord = rot_trans_mmul(textureMatrix, vaUV0);

		#if !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)
			immut uvec2 texels = uvec2(fma(abs(v.coord - mc_midTexCoord), vec2(2 * textureSize(gtexture, 0)), vec2(0.5)));
			v.face_tex_size = bitfieldInsert(texels.x, texels.y, 16, 16);
			v.mid_coord = packUnorm2x16(mc_midTexCoord);
		#endif
	} else gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
}
