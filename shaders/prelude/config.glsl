#define VERSION v // [v]

// LIGHTING
	#define DIR_SL 3.0 // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0 4.25 4.5 4.75 5.0]
	#define DIR_BL 5 // [1 2 3 4 5 6 7 8 9 10]
	#define IND_SL 0.75 // [0.0 0.125 0.25 0.375 0.5 0.625 0.75 0.875 1.0]
	#define IND_BL 0.03 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
	#define AMBIENT 0.05 // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
	#define HAND_LIGHT 5 // [0 1 2 3 4 5 6 7 8 9 10]
	#define SSS 5 // [0 1 2 3 4 5 6 7 8 9 10]
	const float ambientOcclusionLevel = 1.0; // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

	// SHADOW_MAP
		const int shadowMapResolution = 2048; // [128 256 512 1024 2048 4096 8192]
		#define SM_DIST 10 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32]
		#define SM_BLUR 2 // [0 1 2]
		#define SM_FADE_DIST 0.15 // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
		#define SM_ENTITY
		#define SM_PLR
		#define SM_BLOCK_ENTITY

	// LIGHT_LIST
		#define LL_DIST 160 // [32 48 64 80 96 112 128 160 192 224 256]
		#define LL_CAPACITY 5120 // [128 256 512 1024 2048 3072 4096 5120 6144 7168 8192 9216 10240 11264 12288 13312 14336 15360 16384]
		#define MIN_LL_INTENSITY 1 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]
		#define LL_FALLOFF_MARGIN 3 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]
		#define LL_RATE 16 // [2 4 8 16 32 64 128 256]
		#define LOD_FALLOFF 3 // [1 2 3 4 5 6 7]
		#define LAVA_LOD_BIAS 0.8 // [0.0 0.2 0.4 0.6 0.8 1.0 1.2]
		#define LDS_RATIO 0.25 // [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

	// FALLBACK_BLOCK
		#define BL_FALLBACK_R 1.2 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
		#define BL_FALLBACK_G 1.2 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
		#define BL_FALLBACK_B 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

	// CUSTOM_EMISSIVE_BLOCKS
		#define EMISSIVE_REDSTONE_BLOCK
		#define EMISSIVE_EMERALD_BLOCK
		#define EMISSIVE_LAPIS_BLOCK

// POST
	#define SATURATION 100 // [0 10 20 30 40 50 60 70 80 90 100]
	#define RED_MUL 100 // [-100 -90 -80 -70 -60 -50 -40 -30 -20 -10 0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 180 190 200 220 240 260 280 300 320 340 360 380 400]
	#define GREEN_MUL 100 // [-100 -90 -80 -70 -60 -50 -40 -30 -20 -10 0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 180 190 200 220 240 260 280 300 320 340 360 380 400]
	#define BLUE_MUL 100 // [-100 -90 -80 -70 -60 -50 -40 -30 -20 -10 0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 180 190 200 220 240 260 280 300 320 340 360 380 400]
	#define TONEMAP 1 // [0 1 2 3 4]
	#define SHARPNESS 0.3 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
	#define AUTO_EXP 3 // [0 1 2 3 4 5 6 7 8]
	#define AUTO_EXP_SPEED 2.5 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]

	// SMAA
		#define SMAA_THRESHOLD 0.02 // [0.005 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
		#define SMAA_SEARCH 32 // [8 16 32 48 64 80 96 112]
		#define SMAA_SEARCH_DIAG 16 // [0 4 8 12 16 20]
		#define SMAA_CORNER 25 // [0 25 50 75 100]

// ATMOSPHERICS
	#define VL 4 // [0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48]
	#define VL_SAMPLES 1 // [1 2 3]
	/*
		const float sunPathRotation = 25.0; // [-25.0 -20.0 -15.0 -10.0 -5.0 5.0 10.0 15.0 20.0 25.0]
	*/
	#define FOG 2 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
	#define RAIN_FOG 6 // [0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30]
	#define WATER_FOG 20 // [0 5 10 15 20 25 30 35 40 45 50]
	#define SUN_BLOOM 3 // [0 1 2 3 4 5]
	#define SKY_BLOOM 1 // [0 1 2 3 4 5]

// SURFACE
	#define WATER_OPACITY 70 // [50 60 70 80 90 100]
	#define WAVE_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
	#define WAVES 0 // [0 1 2 3 4 5 6 7 8 9 10]
	#define SPECULAR 0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
	#define SM 0 // [0 1 2 3 4 5 6 7 8 9 10]
	#define SM_CH r // [r g b a]
	#define SM_TYPE 2 // [0 1 2]
	#define NORMALS 0 // [0 1 2]

// UTIL
	#define LINE_WIDTH 4 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]
	// #define COMPASS
	// #define LIGHT_LEVELS

// COMPAT
	#define CONST_IMMUT 1 // [0 1 2]
	#define MINMAX_3 2 // [0 1 2 3]
	#define MUL_32x16 2 // [0 1 2 3]
	#define SUBGROUP 2 // [0 1 2 3]
	#define SIZED_16_8
	// #define BUFFER_16_8
	#define ASSUME_NV_GPU_SHADER5
	#define ASSUME_AMD_GPU_SHADER_HALF_FLOAT
	#define ASSUME_AMD_GPU_SHADER_INT16
