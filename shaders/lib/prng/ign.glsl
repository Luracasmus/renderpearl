uniform int frameCounter;

// Interleaved Gradient Noise
// Based on code snippet "Interleaved Gradient Noise, but using fixed point math to replace precision dropoff with overflow/wrap-around." by LowellCamp
// Found at https://discord.com/channels/237199950235041794/525510804494221312/950103097596846081 in the shaderLABS Discord server

float ign(vec2 texel, float time) {
	immut ivec2 components = ivec2(fma(vec2(time), vec2(5.588238), texel)) * ivec2(1125928, 97931);
	immut int internal_modulus = (components.x + components.y) & ((1 << 24) - 1);
	return fract(float(internal_modulus) * (52.9829189 / exp2(24.0)));
}

// https://blog.demofox.org/2022/01/01/interleaved-gradient-noise-a-different-kind-of-low-discrepancy-sequence/
/*
	float ign(vec2 texel, float time) {
		return fract(52.9829189 * fract(dot(fma(time.xx, vec2(5.588238), texel), vec2(0.06711056, 0.00583715))));
	}
*/