vec2 distort(vec2 pos) {
	const float distortion = 0.95;

	// https://www.wikiwand.com/en/articles/Squircle#Fern%C3%A1ndez-Guasti_squircle
	// https://www.desmos.com/3d/5vlbwkxhkb

	// not sure if this actually scales correctly to always prevent artifacts
	const float squareness = 1.0 - 2.0 / shadowDistance;
	const float s = squareness;

	// https://www.wikiwand.com/en/articles/Squircle#Linearizing_squareness
	// const float s_denom = 1.0 - (1.0 - sqrt(2.0)) * squareness;
	// const float s = 2.0 * sqrt((3.0 - 2.0 * sqrt(2.0)) * squareness*squareness - (2.0 - sqrt(2.0)) * squareness) / (s_denom*s_denom);

	immut vec2 pos2 = pos*pos;
	immut float fg_squircle_r = sqrt(pos2.x + pos2.y + sqrt(pos2.x*pos2.x + (2.0 - 4.0 * s*s) * pos2.x * pos2.y + pos2.y*pos2.y)) * inversesqrt(2.0);

	return pos / fma(
		fg_squircle_r,
		distortion,
		1.0 - distortion
	);
}