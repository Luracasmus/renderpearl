#define TINTED
#define TRANSLUCENT

#if IRIS_VERSION < 11007
	#define DEFERRED_IGNORE
#endif

#include "/prog/unlit.fsh"
