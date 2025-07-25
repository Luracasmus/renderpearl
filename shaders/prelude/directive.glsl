// https://github.com/kerudion/chunksfadein/wiki/Iris-API
#define CHUNKS_FADE_IN_NO_MOD_INJECT
#define CHUNKS_FADE_IN_NO_INJECT

/*
	const float shadowIntervalSize = 0.0;

	const bool shadowHardwareFiltering0 = true;
	const bool shadowHardwareFiltering1 = true;

	// these make VL a bit faster with high sample count (if you use a higher LOD) but aren't worth the performance impact otherwise
	// const bool shadowtex0Mipmap = true;
	// const bool shadowtex1Mipmap = true;
	// const bool shadowcolor0Mipmap = true;

	const bool shadowcolor0Clear = true;
	const vec4 shadowcolor0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
	const int shadowcolor0Format = RGB565;

	const bool colortex0Clear = false;
	const int colortex0Format = RGBA8;

	const bool colortex1Clear = false;
	const int colortex1Format = RGBA16F;

	const bool colortex2Clear = false;
	const int colortex2Format = RGBA32UI;
*/

const float shadowDistanceRenderMul = 0.85;

// probably not 100% optimal but i've not noticed any issues
// could be smaller if we cap the sunPathRotation to the current default
/* https://play.rust-lang.org/
	```rust
	const REN_MUL: f64 = 0.85; // shadowDistanceRenderMul
	const MAX_ROT: f64 = 25.0; // max sunPathRotation
	const Y_RANGE: f64 = 384.0;

	fn main() {
		let mut elif = "if";

		let cos_a = (std::f64::consts::PI * 0.25 - MAX_ROT.to_radians()).cos();

		for i in 1..=32 {
			let dist = i * 16;

			println!("#{elif} SM_DIST == {i}");
			println!("	const float shadowDistance = {dist};");

			let visible = dist as f64 * REN_MUL;

			let max_y = visible.min(Y_RANGE);
			let max_xz = (2.0_f64).sqrt() * visible*visible * cos_a;
			let plane = (max_xz*max_xz + max_y*max_y).sqrt().ceil();
			println!("	const float shadowNearPlane = -{plane};");
			println!("	const float shadowFarPlane = {plane};");

			elif = "elif";
		}

		println!("#endif");
	}
	```
*/

#if SM_DIST == 1
	const float shadowDistance = 16;
	const float shadowNearPlane = -23;
	const float shadowFarPlane = 23;
#elif SM_DIST == 2
	const float shadowDistance = 32;
	const float shadowNearPlane = -46;
	const float shadowFarPlane = 46;
#elif SM_DIST == 3
	const float shadowDistance = 48;
	const float shadowNearPlane = -68;
	const float shadowFarPlane = 68;
#elif SM_DIST == 4
	const float shadowDistance = 64;
	const float shadowNearPlane = -91;
	const float shadowFarPlane = 91;
#elif SM_DIST == 5
	const float shadowDistance = 80;
	const float shadowNearPlane = -114;
	const float shadowFarPlane = 114;
#elif SM_DIST == 6
	const float shadowDistance = 96;
	const float shadowNearPlane = -136;
	const float shadowFarPlane = 136;
#elif SM_DIST == 7
	const float shadowDistance = 112;
	const float shadowNearPlane = -159;
	const float shadowFarPlane = 159;
#elif SM_DIST == 8
	const float shadowDistance = 128;
	const float shadowNearPlane = -181;
	const float shadowFarPlane = 181;
#elif SM_DIST == 9
	const float shadowDistance = 144;
	const float shadowNearPlane = -204;
	const float shadowFarPlane = 204;
#elif SM_DIST == 10
	const float shadowDistance = 160;
	const float shadowNearPlane = -227;
	const float shadowFarPlane = 227;
#elif SM_DIST == 11
	const float shadowDistance = 176;
	const float shadowNearPlane = -249;
	const float shadowFarPlane = 249;
#elif SM_DIST == 12
	const float shadowDistance = 192;
	const float shadowNearPlane = -272;
	const float shadowFarPlane = 272;
#elif SM_DIST == 13
	const float shadowDistance = 208;
	const float shadowNearPlane = -295;
	const float shadowFarPlane = 295;
#elif SM_DIST == 14
	const float shadowDistance = 224;
	const float shadowNearPlane = -317;
	const float shadowFarPlane = 317;
#elif SM_DIST == 15
	const float shadowDistance = 240;
	const float shadowNearPlane = -340;
	const float shadowFarPlane = 340;
#elif SM_DIST == 16
	const float shadowDistance = 256;
	const float shadowNearPlane = -362;
	const float shadowFarPlane = 362;
#elif SM_DIST == 17
	const float shadowDistance = 272;
	const float shadowNearPlane = -385;
	const float shadowFarPlane = 385;
#elif SM_DIST == 18
	const float shadowDistance = 288;
	const float shadowNearPlane = -408;
	const float shadowFarPlane = 408;
#elif SM_DIST == 19
	const float shadowDistance = 304;
	const float shadowNearPlane = -430;
	const float shadowFarPlane = 430;
#elif SM_DIST == 20
	const float shadowDistance = 320;
	const float shadowNearPlane = -453;
	const float shadowFarPlane = 453;
#elif SM_DIST == 21
	const float shadowDistance = 336;
	const float shadowNearPlane = -475;
	const float shadowFarPlane = 475;
#elif SM_DIST == 22
	const float shadowDistance = 352;
	const float shadowNearPlane = -498;
	const float shadowFarPlane = 498;
#elif SM_DIST == 23
	const float shadowDistance = 368;
	const float shadowNearPlane = -521;
	const float shadowFarPlane = 521;
#elif SM_DIST == 24
	const float shadowDistance = 384;
	const float shadowNearPlane = -543;
	const float shadowFarPlane = 543;
#elif SM_DIST == 25
	const float shadowDistance = 400;
	const float shadowNearPlane = -566;
	const float shadowFarPlane = 566;
#elif SM_DIST == 26
	const float shadowDistance = 416;
	const float shadowNearPlane = -589;
	const float shadowFarPlane = 589;
#elif SM_DIST == 27
	const float shadowDistance = 432;
	const float shadowNearPlane = -611;
	const float shadowFarPlane = 611;
#elif SM_DIST == 28
	const float shadowDistance = 448;
	const float shadowNearPlane = -634;
	const float shadowFarPlane = 634;
#elif SM_DIST == 29
	const float shadowDistance = 464;
	const float shadowNearPlane = -650;
	const float shadowFarPlane = 650;
#elif SM_DIST == 30
	const float shadowDistance = 480;
	const float shadowNearPlane = -665;
	const float shadowFarPlane = 665;
#elif SM_DIST == 31
	const float shadowDistance = 496;
	const float shadowNearPlane = -680;
	const float shadowFarPlane = 680;
#elif SM_DIST == 32
	const float shadowDistance = 512;
	const float shadowNearPlane = -695;
	const float shadowFarPlane = 695;
#endif
