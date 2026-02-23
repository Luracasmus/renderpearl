// https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/

f16vec2 octa_encode(f16vec3 normal) {
	normal.xy /= dot(abs(normal), f16vec3(1.0));

	if (normal.z < float16_t(0.0)) normal.xy = mix(
		f16vec2(1.0),
		f16vec2(-1.0),
		greaterThanEqual(normal.xy, f16vec2(0.0))
	) * (abs(normal.yx) + float16_t(-1.0));

	return normal.xy;
}

f16vec3 octa_decode(f16vec2 octa_normal) {
	immut f16vec2 abs_on = abs(octa_normal);
	immut float16_t z = float16_t(1.0) - abs_on.x - abs_on.y;

	return f16vec3(fma(max(-z, float16_t(0.0)).xx, mix(
		f16vec2(1.0),
		f16vec2(-1.0),
		greaterThanEqual(octa_normal, f16vec2(0.0))
	), octa_normal), z);
}
