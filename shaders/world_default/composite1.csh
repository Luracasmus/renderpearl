#include "/prelude/core.glsl"

/* SMAA Edge Detection */

layout(local_size_x = 16, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform sampler2D colortex1;
uniform layout(rg8) restrict writeonly image2D edge;

/*
	SMAA Color (redmean) Edge Detection
	https://github.com/Luracasmus/smaa-mc

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

#include "/lib/srgb.glsl"
#include "/lib/redmean.glsl"

void main() {
	immut i16vec2 texel = i16vec2(gl_GlobalInvocationID.xy);

	immut f16vec3 color = srgb(f16vec3(texelFetch(colortex1, texel, 0).rgb));
	immut f16vec3 left = srgb(f16vec3(texelFetchOffset(colortex1, texel, 0, ivec2(-1, 0)).rgb));
	immut f16vec3 top = srgb(f16vec3(texelFetchOffset(colortex1, texel, 0, ivec2(0, -1)).rgb));

	immut f16vec2 delta = f16vec2(
		sq_redmean(color, left),
		sq_redmean(color, top)
	);

	// We square the contrast threshold and LCA factor to compensate for the color difference being squared,
	// making the actual color difference metric regular redmean.
	immut bvec2 edges = greaterThanEqual(delta.xy, f16vec2(SMAA_THRESHOLD*SMAA_THRESHOLD));

	if (any(edges)) {
		const lowp f16vec2 delta_max = max3(
			delta,
			vec2(
				sq_redmean(color, srgb(f16vec3(texelFetchOffset(colortex1, texel, 0, ivec2(1, 0)).rgb))), // Right.
				sq_redmean(color, srgb(f16vec3(texelFetchOffset(colortex1, texel, 0, ivec2(0, 1)).rgb))) // Bottom.
			),
			vec2(
				sq_redmean(left, srgb(f16vec3(texelFetchOffset(colortex1, texel, 0, ivec2(-2, 0)).rgb))), // Left-left.
				sq_redmean(top, srgb(f16vec3(texelFetchOffset(colortex1, texel, 0, ivec2(0, -2)).rgb))) // Top-top.
			)
		);

		immut bvec2 temp = greaterThanEqual(delta, (max(delta_max.x, delta_max.y) / float16_t(SMAA_LCA*SMAA_LCA)).xx);
		immut bvec2 result = bvec2(edges.x && temp.x, edges.y && temp.y); // This is required instead of `result && temp` on AMD, due to different interpretations of the GLSL spec.

		if (any(result)) {
			imageStore(edge, texel, f16vec4(result, 0.0, 0.0));
		}
	}
}
