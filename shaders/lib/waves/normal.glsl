// unused & probably wrong

vec3 wave_normal(vec2 pos) {
	pos += waveState.xy;
	immut vec2 wave = sin(pos + waveState.z) + sin(pos * 0.5 + waveState.z * 3.0);
	immut vec2 dwave_dxy = (cos(pos + waveState.z) + 0.5 * cos(pos * 0.5 + waveState.z * 3.0)) * wave.yx * (float(WAVES) * 0.01);

	return normalize(vec3(
		dwave_dxy.x,
		1.0,
		dwave_dxy.y
	));
}