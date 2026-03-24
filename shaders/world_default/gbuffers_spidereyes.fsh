#define TEXTURED
#define TINTED
#define ALPHA_CHECK

#if IRIS_VERSION < 11007
	#define DEFERRED_IGNORE
#endif

#include "/prog/unlit.fsh"
