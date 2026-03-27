#define ALPHA_CHECK

#if IRIS_VERSION == 11007
	#define TRANSLUCENT
	#include "/prog/lit_forward.fsh"
#else
	#define TEX_ALPHA
	#include "/prog/lit_deferred.fsh"
#endif
