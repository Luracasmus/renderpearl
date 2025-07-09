float rand(vec2 seed) {
	return fract(sin(mod(dot(seed, vec2(12.9898, 78.233)), 3.14)) * 43758.5453);
}
