#define CLRWL
#if COLORWHEEL_VERSION >= 10205
	#include "/prog/lit_deferred.fsh"
#else
	// Avoid missing `gtexture` in vertex stage, fixed in
	// https://github.com/djefrey/Colorwheel/commit/de1da265d4ac0fb6a3e7a4c08af9e147547e58b4
	// (Colorwheel 1.2.5)
	#include "/prog/unlit.fsh"
#endif
