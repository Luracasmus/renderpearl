/*
	https://github.com/Luracasmus/smaa-mc

	Modified, based on "Colour metric" (https://www.compuphase.com/cmetric.htm),
	Copyright (c) 2019–2026 Thiadmer Riemersma,
	licensed under CC BY-SA 3.0 (https://creativecommons.org/licenses/by-sa/3.0/).

	This file is also licensed under CC BY‑SA 3.0 (https://creativecommons.org/licenses/by-sa/3.0/).
	Modifications Copyright (c) 2026 Luracasmus.
*/

// Squared redmean color difference.
float16_t sq_redmean(f16vec3 a, f16vec3 b) {
	immut float16_t r = mix(a.r, b.r, float16_t(0.5)) * float16_t(0.99609375);
	immut f16vec3 d = a - b;

	return dot(d*d, vec3(
		float16_t(2.0) + r,
		float16_t(4.0),
		float16_t(2.99609375) - r
	));
}
