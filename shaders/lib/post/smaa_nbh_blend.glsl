/*
	SMAA Neighborhood Blending
	https://github.com/Luracasmus/grindstone

	Copyright (C) 2013 Jorge Jimenez (jorge@iryoku.com)
	Copyright (C) 2013 Jose I. Echevarria (joseignacioechevarria@gmail.com)
	Copyright (C) 2013 Belen Masia (bmasia@unizar.es)
	Copyright (C) 2013 Fernando Navarro (fernandn@microsoft.com)
	Copyright (C) 2013 Diego Gutierrez (diegog@unizar.es)
	Copyright (C) 2024-2026 Luracasmus

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

uniform sampler2D blendWeightS;

f16vec3 smaa_nbh_blend(sampler2D colortex, i16vec2 texel) {
	immut vec2 texel_size = 1.0 / vec2(unpackUint2x16(uint(packedView)));
	immut vec2 coord = fma(vec2(texel), texel_size, 0.5 * texel_size);

	f16vec4 a = f16vec4(
		texelFetchOffset(blendWeightS, texel, 0, ivec2(1, 0)).w,
		texelFetchOffset(blendWeightS, texel, 0, ivec2(0, 1)).y,
		texelFetch(blendWeightS, texel, 0).zx
	);

	f16vec3 color;

	if (dot(vec4(a), vec4(1.0)) < 1.0e-5) {
		color = f16vec3(texelFetch(colortex, texel, 0).rgb);
	} else {
		immut bool h = max(a.x, a.z) > max(a.y, a.w);

		immut vec4 blend_offset = h ? vec4(a.x, 0.0, a.z, 0.0) : vec4(0.0, a.y, 0.0, a.w);

		f16vec2 blend_weight = h ? a.xz : a.yw;
		blend_weight /= dot(blend_weight, f16vec2(1.0));

		color = blend_weight.x * f16vec3(textureLod(colortex, fma(blend_offset.xy, texel_size, coord), 0.0).rgb)
			+ blend_weight.y * f16vec3(textureLod(colortex, fma(blend_offset.zw, -texel_size, coord), 0.0).rgb);
	};

	return color;
}
