#define ALPHA_CHECK

#if IRIS_VERSION == 11007
	#define TRANSLUCENT
	#include "/prog/lit_forward.fsh"
#else
	#include "/prog/lit_forward.fsh"
#endif
