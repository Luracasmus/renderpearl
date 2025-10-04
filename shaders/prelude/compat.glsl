// see https://gist.github.com/Luracasmus/ff78f1998a5a440899e1904fa23cc9c6

// We sometimes assume support based on device characteristics,
// since it's not always properly advertised by drivers,
// which causes Iris to not define all macros for supported extensions.

#ifdef ASSUME_NV_GPU_SHADER5
#endif
#ifdef ASSUME_AMD_GPU_SHADER_HALF_FLOAT
#endif
#ifdef ASSUME_AMD_GPU_SHADER_INT16
#endif

#if (CONST_IMMUT == 1 && defined MC_GL_VENDOR_NVIDIA) || CONST_IMMUT == 2
	#define immut const
#else
	#define immut
#endif

// It seems like this is always supported on non-NVIDIA drivers.
// Based on: https://opengl.gpuinfo.org/listreports.php?extension=GL_AMD_shader_trinary_minmax
#if (MINMAX_3 >= 1 && defined MC_GL_AMD_shader_trinary_minmax) || (MINMAX_3 >= 2 && !defined MC_GL_VENDOR_NVIDIA && !(defined MC_GL_VENDOR_INTEL && defined MC_OS_WINDOWS)) || MINMAX_3 >= 3
	#extension GL_AMD_shader_trinary_minmax : require
#else
	#define min3(v0, v1, v2) min(v0, min(v1, v2))
	#define max3(v0, v1, v2) max(v0, max(v1, v2))
#endif

// It seems like this is always supported on Mesa drivers for Intel GPUs (excluding some mobile or very old GPUs).
// Based on: https://opengl.gpuinfo.org/listreports.php?extension=GL_INTEL_shader_integer_functions2
#if (MUL_32x16 >= 1 && defined MC_GL_INTEL_shader_integer_functions2) || (MUL_32x16 >= 2 && defined MC_GL_VENDOR_MESA && defined MC_GL_RENDERER_INTEL) || MUL_32x16 >= 3
	#extension GL_INTEL_shader_integer_functions2 : require
#else
	#define multiply32x16(v0, v1) (v0 * v1)
#endif

#if (SUBGROUP >= 1 && defined GL_KHR_shader_subgroup) || (SUBGROUP >= 2 && defined MC_GL_VENDOR_NVIDIA) || SUBGROUP >= 3
	#extension GL_KHR_shader_subgroup_basic : require
	#extension GL_KHR_shader_subgroup_vote : require
#else
	#define subgroupAny(v) (v)
	#define subgroupElect() true
#endif

#ifdef SIZED_16_8
	// It seems like this is always supported on NVIDIA drivers.
	// Based on: https://opengl.gpuinfo.org/listreports.php?extension=GL_NV_gpu_shader5
	#if defined MC_GL_NV_gpu_shader5 || (defined ASSUME_NV_GPU_SHADER5 && defined MC_GL_VENDOR_NVIDIA)
		#extension GL_NV_gpu_shader5 : require
		#define FLOAT16
		#define INT16
		#define INT8
		// #define MAT16 // doesn't seem to work :/
	#endif

	// It seems like this is always supported on Windows with ATI/AMD drivers for Radeon GPUs (excluding some mobile or very old GPUs).
	// Based on: https://opengl.gpuinfo.org/listreports.php?extension=GL_AMD_gpu_shader_half_float
	#if defined MC_GL_AMD_gpu_shader_half_float || (defined ASSUME_AMD_GPU_SHADER_HALF_FLOAT && defined MC_GL_RENDERER_RADEON && defined MC_OS_WINDOWS && (defined MC_GL_VENDOR_AMD || defined MC_GL_VENDOR_ATI))
		#extension GL_AMD_gpu_shader_half_float : require
		#define FLOAT16
		// #define MAT16 // seems to cause some issues with casting :/

		#define AMD_FLOAT16
	#endif

	// Same as above.
	// Based on: https://opengl.gpuinfo.org/listreports.php?extension=GL_AMD_gpu_shader_int16
	#if defined MC_GL_AMD_gpu_shader_int16 || (defined ASSUME_AMD_GPU_SHADER_INT16 && defined MC_GL_RENDERER_RADEON && defined MC_OS_WINDOWS && (defined MC_GL_VENDOR_AMD || defined MC_GL_VENDOR_ATI))
		#extension GL_AMD_gpu_shader_int16 : require
		#define INT16
		#define PACK_INT16

		#define AMD_INT16
	#endif

	#if defined AMD_FLOAT16 && defined AMD_INT16
		#define TRANSMUTE_AND_PACK_INT16
	#endif

	#ifdef MC_GL_EXT_shader_16bit_storage
		#extension GL_EXT_shader_16bit_storage : require
		#define FLOAT16 // How does this interact with trinary min/max?
		#define INT16
	#endif

	#ifdef MC_GL_EXT_shader_8bit_storage
		#extension GL_EXT_shader_8bit_storage : require
		#define INT8
	#endif

	#ifdef MC_GL_EXT_shader_explicit_arithmetic_types_float16
		#extension GL_EXT_shader_explicit_arithmetic_types_float16 : require
		#define FLOAT16
		// #define MAT16
	#endif

	#ifdef MC_GL_EXT_shader_explicit_arithmetic_types_int16
		#extension GL_EXT_shader_explicit_arithmetic_types_int16 : require
		#define INT16
		#define PACK_INT16
	#endif

	#if defined MC_GL_EXT_shader_explicit_arithmetic_types_float16 && defined MC_GL_EXT_shader_explicit_arithmetic_types_int16
		#define TRANSMUTE_AND_PACK_INT16
	#endif

	#ifdef MC_GL_EXT_shader_explicit_arithmetic_types_int8
		#extension GL_EXT_shader_explicit_arithmetic_types_int8 : require
		#define INT8
	#endif
#endif

#ifdef BUFFER_16_8
	// Only used in shaders.properties to allow for smaller buffers. Required since Iris' .properties pre-processor doesn't handle non-option macros, so we can't check for actual support.
	// https://discord.com/channels/774352792659820594/774354522361299006/1360611068812198001 (The Iris Project)
#endif

// Fallback definitions
// WARN: possibly don't cover everything!

#ifndef INT16
	#define int16_t int
	#define i16vec2 ivec2
	#define i16vec3 ivec3
	#define i16vec4 ivec4

	#define uint16_t uint
	#define u16vec2 uvec2
	#define u16vec3 uvec3
	#define u16vec4 uvec4

	// Work around Iris bug.
	// https://discord.com/channels/774352792659820594/774354522361299006/1360611068812198001 (The Iris Project)
	#undef INT16
#endif

#ifndef INT8
	#define int8_t int16_t
	#define i8vec2 i16vec2
	#define i8vec3 i16vec3
	#define i8vec4 i16vec4

	#define uint8_t uint16_t
	#define u8vec2 u16vec2
	#define u8vec3 u16vec3
	#define u8vec4 u16vec4
#endif

#ifndef FLOAT16
	#define float16_t float
	#define f16vec2 vec2
	#define f16vec3 vec3
	#define f16vec4 vec4

	uint packFloat2x16(vec2 v) { return packHalf2x16(v); }
	vec2 unpackFloat2x16(uint v) { return unpackHalf2x16(v); }
#endif

#ifndef MAT16
	#define f16mat2 mat2
	#define f16mat2x3 mat2x3
	#define f16mat2x4 mat2x4

	#define f16mat3x2 mat3x2
	#define f16mat3 mat3
	#define f16mat3x4 mat3x4

	#define f16mat4x2 mat4x2
	#define f16mat4x3 mat4x3
	#define f16mat4 mat4
#endif

#ifndef PACK_INT16
	int packInt2x16(i16vec2 v) {
		immut ivec2 v_i32 = ivec2(v);
		return bitfieldInsert(v_i32.x, v_i32.y, 16, 16);
	}

	i16vec2 unpackInt2x16(int v) { return i16vec2(v & 65535, v >> 16); }

	uint packUint2x16(u16vec2 v) {
		immut uvec2 v_u32 = uvec2(v);
		return bitfieldInsert(v_u32.x, v_u32.y, 16, 16);
	}

	u16vec2 unpackUint2x16(uint v) { return u16vec2(v & 65535u, v >> 16u); }
#endif

#ifndef TRANSMUTE_AND_PACK_INT16
	int16_t float16BitsToInt16(float16_t v) { return int16_t(packFloat2x16(f16vec2(v, 0.0))); }
	i16vec2 float16BitsToInt16(f16vec2 v) { return unpackInt2x16(int(packFloat2x16(v))); }
	i16vec3 float16BitsToInt16(f16vec3 v) { return i16vec3(float16BitsToInt16(v.xy), float16BitsToInt16(v.z)); }
	i16vec4 float16BitsToInt16(f16vec4 v) { return i16vec4(float16BitsToInt16(v.xy), float16BitsToInt16(v.zw)); }

	float16_t int16BitsToFloat16(int16_t v) { return unpackFloat2x16(uint(v)).x; }
	f16vec2 int16BitsToFloat16(i16vec2 v) { return unpackFloat2x16(uint(packInt2x16(v))); }
	f16vec3 int16BitsToFloat16(i16vec3 v) { return f16vec3(int16BitsToFloat16(v.xy), int16BitsToFloat16(v.z)); }
	f16vec4 int16BitsToFloat16(i16vec4 v) { return f16vec4(int16BitsToFloat16(v.xy), int16BitsToFloat16(v.zw)); }

	uint16_t float16BitsToUint16(float16_t v) { return uint16_t(packFloat2x16(f16vec2(v, 0.0))); }
	float16_t uint16BitsToFloat16(uint16_t v) { return unpackFloat2x16(uint(v)).x; }

	u16vec2 float16BitsToUint16(f16vec2 v) { return unpackUint2x16(packFloat2x16(v)); }
	u16vec3 float16BitsToUint16(f16vec3 v) { return u16vec3(float16BitsToUint16(v.xy), float16BitsToUint16(v.z)); }
	u16vec4 float16BitsToUint16(f16vec4 v) { return u16vec4(float16BitsToUint16(v.xy), float16BitsToUint16(v.zw)); }

	f16vec2 uint16BitsToFloat16(u16vec2 v) { return unpackFloat2x16(packUint2x16(v)); }
	f16vec3 uint16BitsToFloat16(u16vec3 v) { return f16vec3(uint16BitsToFloat16(v.xy), uint16BitsToFloat16(v.z)); }
	f16vec4 uint16BitsToFloat16(u16vec4 v) { return f16vec4(uint16BitsToFloat16(v.xy), uint16BitsToFloat16(v.zw)); }
#endif

// #extension GL_EXT_shader_integer_mix : require
// #extension GL_ARB_gpu_shader_int64 : require
// #extension GL_AMD_gpu_shader_int64 : require

// #extension GL_KHR_shader_subgroup_basic : require
// #extension GL_KHR_shader_subgroup_quad : require
// #extension GL_KHR_shader_subgroup_vote : require
// #extension GL_KHR_shader_subgroup_arithmetic: require
