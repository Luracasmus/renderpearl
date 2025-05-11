#if TONEMAP == 1 // Tony McMapface
	uniform sampler3D tmmfLut;
#elif TONEMAP == 4 // SBDT (SomewhatBoringDisplayTransform)
	/*
		https://github.com/bevyengine/bevy/blob/main/crates/bevy_core_pipeline/src/tonemapping/tonemapping_shared.wgsl

		MIT License

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.
	*/

	float sbdt_curve(float v) {
		immut float c = v + v*v + 0.5 * v*v*v;
		return c / (1.0 + c);
	}

	vec3 sbdt_curve(vec3 color) {
		immut vec3 c = color + color*color + 0.5 * color*color*color;
		return c / (1.0 + c);
	}
#endif

#include "/lib/luminance.glsl"

f16vec3 tonemap(f16vec3 color) {
	#if TONEMAP == 0 // Saturate
		//color = color / luminance(color) * min(luminance(color), 1.0); // kinda works
		//color = color / max3(color.r, color.g, color.b) * min(max3(color.r, color.g, color.b), 1.0); // cursed
		return saturate(color);
	#elif TONEMAP == 1 // Tony McMapface
		/*
			https://github.com/h3r2tic/tony-mc-mapface

			Copyright (c) 2023 Tomasz Stachowiak

			Permission is hereby granted, free of charge, to any
			person obtaining a copy of this software and associated
			documentation files (the "Software"), to deal in the
			Software without restriction, including without
			limitation the rights to use, copy, modify, merge,
			publish, distribute, sublicense, and/or sell copies of
			the Software, and to permit persons to whom the Software
			is furnished to do so, subject to the following
			conditions:

			The above copyright notice and this permission notice
			shall be included in all copies or substantial portions
			of the Software.

			THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
			ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
			TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
			PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
			SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
			CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
			OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
			IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
			DEALINGS IN THE SOFTWARE.
		*/

		const float lut_dims = 48.0;

		immut f16vec3 encoded = color / (color + float16_t(1.0));
		immut f16vec3 uv = fma(encoded, float16_t((lut_dims - 1.0) / lut_dims).xxx, float16_t(0.5 / lut_dims).xxx);

		return f16vec3(textureLod(tmmfLut, uv, 0.0).rgb);
	#elif TONEMAP == 2 // Uchimura
		immut vec3 color_f32 = vec3(color);

		/*
			https://github.com/dmnsgn/glsl-tone-map/blob/main/uchimura.glsl

			Copyright (C) 2019 Damien Seguin

			Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

			The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

			THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
		*/

		immut vec3 w0 = 1.0 - smoothstep(0.0, 0.22, color_f32);
		immut vec3 w2 = step(0.532, color_f32);
		const float a = pow(0.22, -0.33);

		return f16vec3(a * pow(color_f32, vec3(1.33)) * w0 + color_f32 * (1.0 - w0 - w2) + fma(exp(0.532/0.468 - color_f32 / 0.468), vec3(-0.468), vec3(1.0)) * w2);
	#elif TONEMAP == 3 // ACES Fitted
		vec3 color_f32 = vec3(color);

		/*
			https://github.com/bevyengine/bevy/blob/main/crates/bevy_core_pipeline/src/tonemapping/tonemapping_shared.wgsl

			MIT License

			Permission is hereby granted, free of charge, to any person obtaining a copy
			of this software and associated documentation files (the "Software"), to deal
			in the Software without restriction, including without limitation the rights
			to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
			copies of the Software, and to permit persons to whom the Software is
			furnished to do so, subject to the following conditions:

			The above copyright notice and this permission notice shall be included in all
			copies or substantial portions of the Software.

			THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
			IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
			FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
			AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
			LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
			OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
			SOFTWARE.
		*/

		// The code below was originally written by Stephen Hill (@self_shadow), who deserves all
		// credit for coming up with this fit and implementing it. Buy him a beer next time you see him. :)

		// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
		const mat3 rgb_to_rrt = mat3(
			0.59719, 0.35458, 0.04823,
			0.07600, 0.90834, 0.01566,
			0.02840, 0.13383, 0.83777
		);

		// ODT_SAT => XYZ => D60_2_D65 => sRGB
		const mat3 odt_to_rgb = mat3(
			1.60475, -0.53108, -0.07367,
			-0.10208, 1.10813, -0.00605,
			-0.00327, -0.07276, 1.07602
		);

		color_f32 *= rgb_to_rrt;

		// Apply RRT and ODT
		immut vec3 a = color_f32 * (color_f32 + 0.0245786) - 0.000090537;
		immut vec3 b = color_f32 * (0.983729 * color_f32 + 0.4329510) + 0.238081;
		color_f32 = a / b;

		return saturate(f16vec3(color_f32 * odt_to_rgb));
	#elif TONEMAP == 4 // SBDT (SomewhatBoringDisplayTransform)
		immut vec3 color_f32 = vec3(color);

		/*
			https://github.com/bevyengine/bevy/blob/main/crates/bevy_core_pipeline/src/tonemapping/tonemapping_shared.wgsl

			By Tomasz Stachowiak

			MIT License

			Permission is hereby granted, free of charge, to any person obtaining a copy
			of this software and associated documentation files (the "Software"), to deal
			in the Software without restriction, including without limitation the rights
			to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
			copies of the Software, and to permit persons to whom the Software is
			furnished to do so, subject to the following conditions:

			The above copyright notice and this permission notice shall be included in all
			copies or substantial portions of the Software.

			THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
			IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
			FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
			AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
			LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
			OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
			SOFTWARE.
		*/

		immut vec3 ycbcr = color_f32 * mat3(
			0.2126, 0.7152, 0.0722,
			-0.1146, -0.3854, 0.5,
			0.5, -0.4542, -0.0458
		);

		immut float bt = sbdt_curve(length(ycbcr.gb) * 2.4);
		immut float desat = max(fma(bt, 0.8, -0.56), 0.0);

		return f16vec3(mix(
			color_f32 * max(0.0, sbdt_curve(ycbcr.r) / max(1.0e-5, dot(color_f32, vec3(0.2126, 0.7152, 0.0722)))),
			sbdt_curve(mix(color_f32, ycbcr.rrr, desat * desat)),
			bt * bt
		) * 0.97);
	#endif
}
