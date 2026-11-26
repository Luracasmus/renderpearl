#include "/lib/post/tonemap.glsl"

#if AUTO_EXP
	#include "/buf/auto_exp.glsl"

	uniform bool autoExpSample;
#endif

#ifdef COMPASS
	uniform vec3 playerLookVector;
#endif

f16vec3 process_color(f16vec3 color, i16vec2 texel) {
	/*
		vec2 coord = fma(vec2(texel), 2.0 / vec2(unpackUint2x16(uint(packedView))), vec2(-1.0));

		const float markiplier = 0.1;

		coord *= fma(length(coord), markiplier, 1.0 - markiplier);
		immut vec2 abs_coord = abs(coord);
		coord *= fma(max(abs_coord.x, abs_coord.y), markiplier, 1.0 - markiplier);

		coord = fma(mix(coord, mod(fma(coord, vec2(0.5), vec2(0.5)), 0.25), 0.5), vec2(0.5), vec2(0.5));
		i16vec2 distorted_texel = i16vec2(fma(coord, vec2(unpackUint2x16(uint(packedView))), vec2(0.5)));
	*/

	#if RED_MUL != 100 || GREEN_MUL != 100 || BLUE_MUL != 100
		color *= f16vec3(0.01 * vec3(RED_MUL, GREEN_MUL, BLUE_MUL));
		// TODO: Fix negative muls so that they actually invert the color.
	#endif

	#if SATURATION != 100 || AUTO_EXP
		immut float16_t luma = luminance(color);
	#endif

	#if SATURATION != 100
		color = mix(luma.rrr, color, float16_t(SATURATION * 0.01));
	#endif

	#if AUTO_EXP
		if (autoExpSample) {
			if ((texel & int16_t(63u)) == i16vec2(0u)) {
				// Clamp to avoid over- or underflowing the counter.
				atomicAdd(auto_exp.sum_log_luma, int(roundEven(clamp(log2(luma), float16_t(-14.0), float16_t(14.0)) * float16_t(256.0))));

				// DEBUG: sample positions:
				// color = f16vec3(1.0);
			}
		}

		color *= float16_t(subgroupBroadcastFirst(auto_exp.exposure));
	#endif

	#ifdef COMPASS
		immut vec2 coord = (vec2(texel) + 0.5) / vec2(view_size());

		const vec2 comp_pos = vec2(0.5, 0.9);
		const vec2 comp_size = vec2(0.1, 0.01);
		const float comp_line = 0.01;

		immut vec2 comp_dist = (coord - comp_pos) / comp_size;
		immut vec2 abs_dist = abs(comp_dist);

		if (max(abs_dist.x, abs_dist.y) < 1.0) {
			const float inv_comp_line = 1.0 - comp_line;

			immut float ang = PI * -0.5 * comp_dist.x;
			immut float s = sin(ang);
			immut float c = cos(ang);
			immut vec2 dir = mat2(c, -s, s, c) * normalize(playerLookVector.xz);

			vec3 comp_color = vec3(0.0);

			/*
				W - < x > + E
				N - < z > + S
			*/

			comp_color.r += saturate(-dir.y - inv_comp_line);
			comp_color.rg += saturate(dir.x - inv_comp_line);
			comp_color.rb += saturate(-dir.x - inv_comp_line);
			comp_color.gb += saturate(dir.y - inv_comp_line);

			comp_color = fma(comp_color, (1.0 / comp_line).xxx, vec3(max(0.1 - abs_dist.y, 0.0) * 10.0));

			color = f16vec3(mix(color, comp_color, luminance(comp_color) * step(0.0, 1.5 - abs_dist.x - abs_dist.y))); // TODO: Make actually float16_t.
		}
	#endif

	return tonemap(color);
}
