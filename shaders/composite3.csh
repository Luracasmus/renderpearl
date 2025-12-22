#include "/prelude/core.glsl"

/* SMAA Neighborhood Blending & CAS */

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform layout(rgba8) restrict writeonly image2D colorimg0;
uniform sampler2D blendWeightS, colortex1;

#include "/lib/view_size.glsl"
#include "/lib/srgb.glsl"
#include "/lib/luminance.glsl"

struct Shared {
	f16vec3[gl_WorkGroupSize.x + 2][gl_WorkGroupSize.y + 2] nbh;
}; shared Shared sh;

/*
	SMAA Neighborhood Blending
	https://github.com/Luracasmus/smaa-mc/blob/main/shaders/composite2.csh

	Copyright (C) 2013 Jorge Jimenez (jorge@iryoku.com)
	Copyright (C) 2013 Jose I. Echevarria (joseignacioechevarria@gmail.com)
	Copyright (C) 2013 Belen Masia (bmasia@unizar.es)
	Copyright (C) 2013 Fernando Navarro (fernandn@microsoft.com)
	Copyright (C) 2013 Diego Gutierrez (diegog@unizar.es)
	Copyright (C) 2024-2025 Luracasmus

	Permission is hereby granted, free of charge, to any person obtaining a copy
	this software and associated documentation files (the "Software"), to deal in
	the Software without restriction, including without limitation the rights to
	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
	the Software, and to permit persons to whom the Software is furnished to do so,
	subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software. As clarification, there is no
	requirement that the copyright notice and permission be included in binary
	distributions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
	FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
f16vec3 smaa_nbh_blend(i16vec2 texel, vec2 texel_size, vec2 coord) {
	f16vec4 a = f16vec4(
		texelFetchOffset(blendWeightS, texel, 0, ivec2(1, 0)).w,
		texelFetchOffset(blendWeightS, texel, 0, ivec2(0, 1)).y,
		texelFetch(blendWeightS, texel, 0).zx
	);

	f16vec3 color;

	if (dot(vec4(a), vec4(1.0)) < 1.0e-5) {
		color = f16vec3(texelFetch(colortex1, texel, 0).rgb);
	} else {
		immut bool h = max(a.x, a.z) > max(a.y, a.w);

		immut vec4 blend_offset = h ? vec4(a.x, 0.0, a.z, 0.0) : vec4(0.0, a.y, 0.0, a.w);

		f16vec2 blend_weight = h ? a.xz : a.yw;
		blend_weight /= dot(blend_weight, f16vec2(1.0));

		color = blend_weight.x * f16vec3(textureLod(colortex1, fma(blend_offset.xy, texel_size, coord), 0.0).rgb)
			+ blend_weight.y * f16vec3(textureLod(colortex1, fma(blend_offset.zw, -texel_size, coord), 0.0).rgb);
	};

	return color;
}

void main() {
	immut u8vec2 nbh_pos = u8vec2(gl_LocalInvocationID.xy) + uint8_t(1u);
	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);
	immut vec2 texel_size = 1.0 / vec2(view_size());
	immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);

	f16vec3 color = smaa_nbh_blend(texel, texel_size, coord);
	sh.nbh[nbh_pos.x][nbh_pos.y] = color;

	i8vec2 border_offset;
	bool is_border;
	#define BORDER_OP(offset) { border_offset = i8vec2(offset); is_border = true; }
	#define NON_BORDER_OP { is_border = false; }
	#include "/lib/nbh/border_cornered.glsl"

	if (is_border) {
		immut i16vec2 border_texel = texel + i16vec2(border_offset);
		immut vec2 border_coord = fma(vec2(border_texel), texel_size, 0.5 * texel_size);

		immut f16vec3 border_color = smaa_nbh_blend(border_texel, texel_size, border_coord);

		immut u8vec2 border_pos = u8vec2(i8vec2(nbh_pos) + i8vec2(border_offset));
		sh.nbh[border_pos.x][border_pos.y] = border_color;
	}

	barrier();

	/*
		FidelityFX Contrast Adaptive Sharpening 1.2
		https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/main/sdk/include/FidelityFX/gpu/cas/ffx_cas.h#L107

		Copyright (C) 2024 Advanced Micro Devices, Inc.

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files(the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions :

		The above copyright notice and this permission notice shall be included in
		all copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
		THE SOFTWARE.
	*/ {
		// a b c
		// d e f
		// g h i
		immut f16vec3[3][3] cas_nbh = f16vec3[3][3](f16vec3[3](
			sh.nbh[nbh_pos.x - uint8_t(1u)][nbh_pos.y - uint8_t(1u)],
			sh.nbh[nbh_pos.x - uint8_t(1u)][nbh_pos.y],
			sh.nbh[nbh_pos.x - uint8_t(1u)][nbh_pos.y + uint8_t(1u)]
		), f16vec3[3](
			sh.nbh[nbh_pos.x][nbh_pos.y - uint8_t(1u)],
			color,
			sh.nbh[nbh_pos.x][nbh_pos.y + uint8_t(1u)]
		), f16vec3[3](
			sh.nbh[nbh_pos.x + uint8_t(1u)][nbh_pos.y - uint8_t(1u)],
			sh.nbh[nbh_pos.x + uint8_t(1u)][nbh_pos.y],
			sh.nbh[nbh_pos.x + uint8_t(1u)][nbh_pos.y + uint8_t(1u)]
		));

		// Soft min. and max.
		//  a b c             b
		//  d e f * 0.5  +  d e f * 0.5
		//  g h i             h
		// These are 2.0x bigger (factored out the extra multiply).
		f16vec3 minimum = min3(min3(cas_nbh[0][1], cas_nbh[1][1], cas_nbh[2][1]), cas_nbh[1][0], cas_nbh[1][2]);
		minimum += min3(min3(minimum, cas_nbh[0][0], cas_nbh[2][0]), cas_nbh[0][2], cas_nbh[2][2]);

		f16vec3 maximum = max3(max3(cas_nbh[0][1], cas_nbh[1][1], cas_nbh[2][1]), cas_nbh[1][0], cas_nbh[1][2]);
		maximum += max3(max3(maximum, cas_nbh[0][0], cas_nbh[2][0]), cas_nbh[0][2], cas_nbh[2][2]);

		// Smooth minimum distance to signal limit divided by smooth max.
		immut f16vec3 amplify = sqrt(saturate(min(minimum, float16_t(2.0) - maximum) / maximum));

		// Filter shape:
		// 0 w 0
		// w 1 w
		// 0 w 0
		const float16_t sharpness = float16_t(-1.0 / mix(8.0, 5.0, SHARPNESS));
		immut float16_t weight = sharpness * luminance(amplify);
		immut float16_t rcp_rcp_weight = fma(weight, float16_t(4.0), float16_t(1.0)); // This naming is cursed.

		color = saturate(((cas_nbh[1][0] + cas_nbh[0][1] + cas_nbh[2][1] + cas_nbh[1][2]) * weight + cas_nbh[1][1]) / rcp_rcp_weight);
	}

	// DEBUG: work groups.
	// color.rb += vec2(equal(gl_LocalInvocationID.xy, uvec2(0u)));

	imageStore(colorimg0, texel, f16vec4(srgb(color), 0.0));
}
