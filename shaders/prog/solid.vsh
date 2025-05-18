#include "/prelude/core.glsl"

#ifdef EMISSIVE_REDSTONE_BLOCK
#endif
#ifdef EMISSIVE_EMERALD_BLOCK
#endif
#ifdef EMISSIVE_LAPIS_BLOCK
#endif

out gl_PerVertex {
	vec4 gl_Position;
};

uniform float day, farSquared;
uniform vec3 cameraPositionFract, shadowLightDirectionPlr;
uniform mat4 gbufferModelViewInverse, modelViewMatrix, projectionMatrix, shadowModelView, textureMatrix;

#if defined TERRAIN || (HAND_LIGHT && defined HAND) || (!defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP))
	uniform sampler2D gtexture;
#endif

#ifdef HAND
	uniform int handLightLevel;

	#if HAND_LIGHT
		#include "/buf/hand_light.glsl"
	#endif
#endif

#ifdef TERRAIN
	#include "/buf/index.glsl"

	uniform bool rebuildIndex;
	uniform vec3 cameraPosition, chunkOffset;

	in vec2 mc_Entity;
	in vec4 at_midBlock;

	#include "/lib/prng/pcg.glsl"

	#if WAVES && defined SOLID_TERRAIN
		#include "/lib/waves/offset.glsl"
	#endif
#endif

#ifdef ENTITY_COLOR
	uniform vec4 entityColor;
#endif

#if defined TERRAIN || (HAND_LIGHT && defined HAND) || (!defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP))
	in vec2 mc_midTexCoord;
#endif

in vec2 vaUV0;
in vec3 vaPosition;
in vec4 vaColor;

#ifndef NO_NORMAL
	uniform mat3 normalMatrix;

	#include "/lib/tbn/vsh.glsl"
#endif

out VertexData {
	layout(location = 1, component = 0) vec2 coord;

	#ifdef HAND
		layout(location = 5, component = 0) flat vec2 light;
		layout(location = 2, component = 0) flat vec3 tint;
	#else
		layout(location = 1, component = 2) vec2 light;
		layout(location = 2, component = 0) vec3 tint;

		#ifdef TERRAIN
			layout(location = 2, component = 3) float ao;
		#endif
	#endif

	layout(location = 3, component = 0) vec3 s_screen;

	#if !defined NO_NORMAL && !(NORMALS == 1 && defined MC_NORMAL_MAP)
		layout(location = 0, component = 3) flat uint mid_coord;
		layout(location = 4, component = 0) flat uint face_tex_size;
	#endif
} v;

#include "/lib/mmul.glsl"
#include "/lib/luminance.glsl"
#include "/lib/srgb.glsl"
#include "/lib/sm/distort.glsl"
#include "/lib/sm/bias.glsl"
#include "/lib/norm_uv2.glsl"

void main() {
	vec3 model = vaPosition;

	#ifdef TERRAIN
		model += chunkOffset;

		#if WAVES && defined SOLID_TERRAIN
			if (mc_Entity.y == 1.0) model.y += wave(model.xz);
		#endif
	#endif

	if (dot(model.xz, model.xz) < farSquared) {
		immut vec3 view = rot_trans_mmul(modelViewMatrix, model);
		immut vec4 clip = proj_mmul(projectionMatrix, view);
		gl_Position = clip;

		v.coord = rot_trans_mmul(textureMatrix, vaUV0);
		v.light = norm_uv2();

		f16vec3 color = f16vec3(vaColor.rgb);
		#ifdef ENTITY_COLOR
			color = mix(color, f16vec3(entityColor.rgb), float16_t(entityColor.a));
		#endif
		v.tint = vec3(color);

		immut vec3 pe = mat3(gbufferModelViewInverse) * view;
		immut f16vec3 abs_pe = abs(f16vec3(pe));
		immut float16_t chebyshev_dist = max3(abs_pe.x, abs_pe.y, abs_pe.z);

		#ifndef NO_NORMAL
			immut mat3 normal_model_view_inverse = mat3(gbufferModelViewInverse) * normalMatrix;
			immut f16vec3 w_normal = f16vec3(normal_model_view_inverse * normalize(vaNormal));
			immut f16vec3 w_tangent = f16vec3(normal_model_view_inverse * normalize(at_tangent.xyz));

			init_tbn(w_normal, w_tangent); // this must run before writing to `v_tbn.handedness_and_misc`

			#if !(NORMALS == 1 && defined MC_NORMAL_MAP)
				immut uvec2 texels = uvec2(fma(abs(v.coord - mc_midTexCoord), vec2(2 * textureSize(gtexture, 0)), vec2(0.5)));
				v.face_tex_size = bitfieldInsert(texels.x, texels.y, 16, 16);
				v.mid_coord = packUnorm2x16(mc_midTexCoord);
			#endif

			#ifdef HAND
				v_tbn.handedness_and_misc = bitfieldInsert(v_tbn.handedness_and_misc, uint(handLightLevel), 1, 4);

				#if HAND_LIGHT
					if (handLightLevel > 0) {
						immut uvec3 scaled_color = uvec3(fma(linear(vaColor.rgb * textureLod(gtexture, mix(v.coord, mc_midTexCoord, 0.5), 3.0).rgb), vec3(255.0), vec3(0.5)));

						atomicAdd(hand_light.data.r, scaled_color.r);
						atomicAdd(hand_light.data.g, scaled_color.g);
						atomicAdd(hand_light.data.b, scaled_color.b);
						atomicAdd(hand_light.data.a, 1u);
					}
				#endif
			#elif defined TERRAIN
				v.ao = vaColor.a;

				#if !(SM && defined MC_SPECULAR_MAP)
					immut f16vec3 avg_col = color * f16vec3(textureLod(gtexture, mc_midTexCoord, 4.0).rgb);
					immut uint scaled_avg_luma = uint(fma(luminance(avg_col), float16_t(8191.0), float16_t(0.5)));
					v_tbn.handedness_and_misc = bitfieldInsert(v_tbn.handedness_and_misc, scaled_avg_luma, 5, 13);
				#endif

				float16_t norm_emission = min((max(float16_t(mc_Entity.x), float16_t(0.0)) + float16_t(at_midBlock.w)) / float16_t(15.0), float16_t(1.0));
				v.light.x = min(fma(float16_t(norm_emission), float16_t(0.3), max(v.light.x, norm_emission)), float16_t(1.0));

				immut uint emission = uint(fma(norm_emission, float16_t(15.0), float16_t(0.5))); // bring into 4-bit-representable range and round
				v_tbn.handedness_and_misc = bitfieldInsert(v_tbn.handedness_and_misc, emission, 1, 4);

				if (rebuildIndex) { // only rebuild the index once every INDEX_RATE frames
					immut f16vec3 view_f16 = f16vec3(view);

					if (
						// run once per face
						(gl_VertexID & 3) == 1 && // gl_VertexID % 4 == 1
						// cull too weak or non-lights
						emission >= MIN_INDEX_LL &&
						// cull outside INDEX_DIST using Chebyshev distance
						chebyshev_dist < float16_t(INDEX_DIST) &&
						// cull behind camera outside of illumination range
						(view_f16.z < float16_t(0.0) || dot(abs_pe, f16vec3(1.0)) <= float16_t(emission))
					) {
						immut bool fluid = mc_Entity.y == 1.0;
						immut uvec3 seed = uvec3(ivec3(0.5 + cameraPosition + pe));

						// LOD culling
						// increase times two each LOD
						// the fact that the values resulting from higher LODs are divisible by the lower ones means that no lights will appear only further away
						if (uint8_t(pcg(seed.x + pcg(seed.y + pcg(seed.z)))) % (uint8_t(1u) << uint8_t(min(7.0, fma(
							(fluid ? float16_t(LAVA_LOD_BIAS) : float16_t(0.0)) + length(view_f16) / float16_t(INDEX_DIST),
							float16_t(LOD_FALLOFF),
							float16_t(0.5)
						)))) == uint8_t(0u)) {
							#if SM && defined MC_SPECULAR_MAP
								immut f16vec3 avg_col = f16vec3(textureLod(gtexture, mc_midTexCoord, 4.0).rgb);
							#endif

							immut uint i = atomicAdd(index.queue, 1u);

							immut uvec3 light_pe = uvec3(clamp(fma(at_midBlock.xyz, vec3(1.0/64.0), 256.0 + pe + cameraPositionFract), 0.0, 511.5)); // this feels slightly cursed but it works // somehow
							index.data[i] = bitfieldInsert(
								bitfieldInsert(
									bitfieldInsert(bitfieldInsert(light_pe.x, light_pe.y, 9, 9), light_pe.z, 18, 9), // color
									emission, 27, 4 // intensity
								),
								uint(fluid), 31, 1 // "wide" flag (currently set for lava)
							);

							immut uvec3 col = uvec3(fma(linear(color * avg_col), f16vec3(31.0, 63.0, 31.0), f16vec3(0.5)));
							index.color[i] = uint16_t(bitfieldInsert(bitfieldInsert(col.g, col.r, 6, 5), col.b, 11, 5));
						}
					}
				}
			#endif
		#endif

		if (chebyshev_dist < float16_t(shadowDistance * shadowDistanceRenderMul)) {
			#ifdef NO_NORMAL
				immut f16vec3 w_normal = f16vec3(mat3(gbufferModelViewInverse) * vec3(0.0, 0.0, 1.0));
			#endif

			// todo!() this bias is better than before but it would probably be best to do it in shadow screen space and offset a scaled amount of texels
			immut f16vec2 bias = shadow_bias(dot(w_normal, f16vec3(shadowLightDirectionPlr)));

			vec3 s_ndc = shadow_proj_scale * (mat3(shadowModelView) * rot_trans_mmul(gbufferModelViewInverse, view));
			s_ndc.xy = distort(s_ndc.xy);

			s_ndc = fma(mat3(shadowModelView) * vec3(bias.y * w_normal), shadow_proj_scale, s_ndc);
			// s_ndc.z += float(bias.x); // doesn't really seem to help :/

			v.s_screen = fma(s_ndc, vec3(0.5), vec3(0.5));
		}
	} else gl_Position = vec4(0.0/0.0, 0.0/0.0, 1.0/0.0, 1.0);
}
