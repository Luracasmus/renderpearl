/*
	FidelityFX Contrast Adaptive Sharpening 1.2
	https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/v1.1.4/sdk/include/FidelityFX/gpu/cas/ffx_cas.h#L107

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
*/

f16vec3 ffx_cas(sampler2D colortex, i16vec2 texel) {
	// a b c
	// d e f
	// g h i
	immut f16vec3 b = f16vec3(texelFetchOffset(colortex, texel, 0, ivec2(0, -1)).rgb);
	immut f16vec3 d = f16vec3(texelFetchOffset(colortex, texel, 0, ivec2(-1, 0)).rgb);
	immut f16vec3 e = f16vec3(texelFetch(colortex, texel, 0).rgb);
	immut f16vec3 f = f16vec3(texelFetchOffset(colortex, texel, 0, ivec2(1, -1)).rgb);
	immut f16vec3 h = f16vec3(texelFetchOffset(colortex, texel, 0, ivec2(0, 1)).rgb);

	// Soft min. and max.
	//  a b c             b
	//  d e f * 0.5  +  d e f * 0.5
	//  g h i             h
	// These are 2.0x bigger (factored out the extra multiply).
	float16_t minimum = min3(min3(d.g, e.g, f.g), b.g, h.g);
	float16_t maximum = max3(max3(d.g, e.g, f.g), b.g, h.g);

	#ifdef CAS_BETTER_DIAGONALS // TODO: Make configurable.
		immut float16_t a = texelFetchOffset(colortex, texel, 0, ivec2(-1, -1)).g;
		immut float16_t c = texelFetchOffset(colortex, texel, 0, ivec2(1, -1)).g;
		immut float16_t g = texelFetchOffset(colortex, texel, 0, ivec2(-1, 1)).g;
		immut float16_t i = texelFetchOffset(colortex, texel, 0, ivec2(1, 1)).g;.

		minimum += min(minimum, min(min3(a, c, g), i));
		maximum += max(maximum, max(max3(a, c, g), i));
	#endif

	// Smooth minimum distance to signal limit divided by smooth max.
	immut float16_t amplify = sqrt(saturate(min(minimum, float16_t(2.0) - maximum) / maximum));

	// Filter shape:
	// 0 w 0
	// w 1 w
	// 0 w 0
	immut float16_t sharpness = float16_t(-1.0 / mix(8.0, 5.0, CAS_SHARPNESS));
	immut float16_t weight = sharpness * amplify;
	immut float16_t rcp_rcp_weight = fma(weight, float16_t(4.0), float16_t(1.0)); // This naming is cursed.

	return saturate(
		((b + d + f + h) * weight + e) / rcp_rcp_weight
	);
}
