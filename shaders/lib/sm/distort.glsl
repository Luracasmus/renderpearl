// Distortion factor for multiplication with shadow space position.
// `pos` should be in clip or NDC space (which are the exact same in RenderPearl).
float distortion(vec2 pos) {
	const float distortion = 0.95;

	// https://www.wikiwand.com/en/articles/Squircle#Fern%C3%A1ndez-Guasti_squircle
	// https://www.desmos.com/3d/5vlbwkxhkb

	// Not sure if this actually scales correctly to always prevent artifacts.
	const float squareness = 1.0 - 2.0 / shadowDistance;
	const float s = squareness;

	// https://www.wikiwand.com/en/articles/Squircle#Linearizing_squareness
	// const float s_denom = 1.0 - (1.0 - sqrt(2.0)) * squareness;
	// const float s = 2.0 * sqrt((3.0 - 2.0 * sqrt(2.0)) * squareness*squareness - (2.0 - sqrt(2.0)) * squareness) / (s_denom*s_denom);

	immut vec2 pos2 = pos*pos;
	immut float a = pos2.x + pos2.y;
	immut float fg_squircle_r = inversesqrt(2.0) * sqrt(a + sqrt(a*a + (-4.0 * s*s) * pos2.x * pos2.y));
	// immut vec2 pos4 = pos2*pos2;
	// immut float fg_squircle_r = sqrt(pos2.x + pos2.y + sqrt(pos4.x + (2.0 - 4.0 * s*s) * pos2.x * pos2.y + pos4.y)) * inversesqrt(2.0);

	return 1.0 / fma(
		fg_squircle_r,
		distortion,
		1.0 - distortion
	);
}
