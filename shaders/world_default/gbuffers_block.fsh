#define ALPHA_CHECK

#if IRIS_VERSION == 11007
	#define TRANSLUCENT
	#include "/prog/lit.fsh"
#else
	#include "/prog/lit.fsh"
#endif
