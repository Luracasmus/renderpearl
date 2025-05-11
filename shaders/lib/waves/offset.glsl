uniform vec3 waveState;

float wave(vec2 pos) {
	pos += waveState.xy;
	pos = sin(pos + waveState.z) + sin(pos * 0.5 + waveState.z * 3.0);
	return fma(pos.x, pos.y, -1.0) * (float(WAVES) * 0.01);
}