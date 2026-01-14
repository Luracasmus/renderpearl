#define PI 3.14159265358979323846264338327950288
#define LOG2_E 1.44269504088896340735992468100189214

const float16_t min_n_dot_l = float16_t(0.0001);

// Because we use orthographic projection with constant parameters we can use this instead of ´shadowProjection´.
const vec3 shadow_proj_scale = vec3(vec2(1.0 / shadowDistance), -2.0 / (shadowFarPlane - shadowNearPlane));

// Functions to simplify use of instruction arguments that make clamping essentially free:
// See 'CLMP' in RDNA3.5 or 'CM' in RDNA4, for example.
// Beware that clamping/saturation range depends on type.

float saturate(float v) { return clamp(v, 0.0, 1.0); }
vec2 saturate(vec2 v) { return clamp(v, 0.0, 1.0); }
vec3 saturate(vec3 v) { return clamp(v, 0.0, 1.0); }
vec4 saturate(vec4 v) { return clamp(v, 0.0, 1.0); }

int saturate(int v) { return clamp(v, -0x80000000, 0x7FFFFFFF); }
ivec2 saturate(ivec2 v) { return clamp(v, -0x80000000, 0x7FFFFFFF); }
ivec3 saturate(ivec3 v) { return clamp(v, -0x80000000, 0x7FFFFFFF); }
ivec4 saturate(ivec4 v) { return clamp(v, -0x80000000, 0x7FFFFFFF); }

uint saturate(uint v) { return clamp(v, 0u, 0xFFFFFFFFu); }
uvec2 saturate(uvec2 v) { return clamp(v, 0u, 0xFFFFFFFFu); }
uvec3 saturate(uvec3 v) { return clamp(v, 0u, 0xFFFFFFFFu); }
uvec4 saturate(uvec4 v) { return clamp(v, 0u, 0xFFFFFFFFu); }

#ifdef FLOAT16
	float16_t saturate(float16_t v) { return clamp(v, float16_t(0.0), float16_t(1.0)); }
	f16vec2 saturate(f16vec2 v) { return clamp(v, float16_t(0.0), float16_t(1.0)); }
	f16vec3 saturate(f16vec3 v) { return clamp(v, float16_t(0.0), float16_t(1.0)); }
	f16vec4 saturate(f16vec4 v) { return clamp(v, float16_t(0.0), float16_t(1.0)); }
#endif

#ifdef INT16
	int16_t saturate(int16_t v) { return clamp(v, int16_t(-0x8000), int16_t(0x7FFF)); }
	i16vec2 saturate(i16vec2 v) { return clamp(v, int16_t(-0x8000), int16_t(0x7FFF)); }
	i16vec3 saturate(i16vec3 v) { return clamp(v, int16_t(-0x8000), int16_t(0x7FFF)); }
	i16vec4 saturate(i16vec4 v) { return clamp(v, int16_t(-0x8000), int16_t(0x7FFF)); }

	uint16_t saturate(uint16_t v) { return clamp(v, uint16_t(0u), uint16_t(0xFFFFu)); }
	u16vec2 saturate(u16vec2 v) { return clamp(v, uint16_t(0u), uint16_t(0xFFFFu)); }
	u16vec3 saturate(u16vec3 v) { return clamp(v, uint16_t(0u), uint16_t(0xFFFFu)); }
	u16vec4 saturate(u16vec4 v) { return clamp(v, uint16_t(0u), uint16_t(0xFFFFu)); }
#endif

#ifdef INT8
	int8_t saturate(int8_t v) { return clamp(v, int8_t(-0x80), int8_t(0x7F)); }
	i8vec2 saturate(i8vec2 v) { return clamp(v, int8_t(-0x80), int8_t(0x7F)); }
	i8vec3 saturate(i8vec3 v) { return clamp(v, int8_t(-0x80), int8_t(0x7F)); }
	i8vec4 saturate(i8vec4 v) { return clamp(v, int8_t(-0x80), int8_t(0x7F)); }

	uint8_t saturate(uint8_t v) { return clamp(v, uint8_t(0u), uint8_t(0xFFu)); }
	u8vec2 saturate(u8vec2 v) { return clamp(v, uint8_t(0u), uint8_t(0xFFu)); }
	u8vec3 saturate(u8vec3 v) { return clamp(v, uint8_t(0u), uint8_t(0xFFu)); }
	u8vec4 saturate(u8vec4 v) { return clamp(v, uint8_t(0u), uint8_t(0xFFu)); }
#endif
