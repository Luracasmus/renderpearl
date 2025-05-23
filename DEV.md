# Technical Overview

## Pipeline

> X marks the spot... where a write happens (in the buffer corresponding to the line)

### Shadow & Solid Geometry

```
shadow*   : >-*-shadow-X-*--┬--------------*->
gtexture  : >-*--┴-------*-gbuffers(solid) *
specular  : >-*----------*--┘|      |||||  *
normals   : >-*----------*---┘      |||||  *
colortex1 :   *          *          ||||└X-*->
colortex2 :   *          *          |||└X--*->
colortex3 :   *          *          ||└X---*->
lightIndex: >-*----------*----------┼X-----*->
handLight : >-*----------*----------X------*->
[Barriers]: [ X          X                 X ]
              |          └> Solid geometry
              └> Shadow geometry
```

### Deferred Processing

```
indirectDispatch: >-*------┬-----X-*---┬---------------*->
indirectControl :   *      |┌----X-*--┐|               *
colortex1       : >-*-deferred---X-*-deferred1-------X-*->
lightIndex      : >-*-deferred_a-X-*--┘|||             *
handLight       : >-*--------------*---┘||             *
colortex2       : >-*--------------*----┘|             *
colortex3       : >-*--------------*-----┘             *
[Barriers]      : [ X              X                   X ]
                    |              └> Deferred lighting
                    └> Indirect dispatch setup, light index deduplication, and sky
```

### Translucent Geometry

```
handLight : >-*----┐                    *
lightIndex: >-*---┐|                    *
shadow*   : >-*--┐||                    *
colortex1 : >-*-gbuffers(translucent)-X-*->
gtexture  : >-*--┘||                    *
specular  : >-*---┘|                    *
normals   : >-*----┘                    *
[Barriers]: [ X                         X ]
              └> Translucent geometry
```

### Post-Processing

```
handLight       :   *             *              *  ┌-----------X-*--------------*->
indirectDispatch:   *             *              *  |┌----------X-*--------------*->
autoExp         : >-*---┬-------X-*--------------*-composite2_a-X-*--------------*->
depthtex0       : >-*--┐|         *              *                *              *
colortex0       :   *  ||         *              *                * composite3-X-*->
colortex1       : >-*-composite-X-*--┬-----------*----------------*--┘|          *
edge            :   *             * composite1-X-*--┐             *   |          *
blendWeight     :   *             *              * composite2---X-*---┘          *
areatex         : >-*-------------*--------------*--┘|            *              *
searchtex       : >-*-------------*--------------*---┘            *              *
[Barriers]      : [ X             X              X                X              X ]
                    |             |              |                └> SMAA neighborhood blending, and CAS
                    |             |              └> SMAA blend weight calculation, automatic exposure geometric average, and atomic counter zero
                    |             └> SMAA edge detection
                    └> Fog, volumetric light, automatic exposure luma sum and application, and color-related post-processing
```

## Packing & Layout

> Remember "When bit-packing fields into a G-Buffer, put highly correlated bits in the Most Significant Bits (MSBs) and noisy data in the Least Significant Bits (LSBs)." (https://gpuopen.com/learn/rdna-performance-guide/)

```
┌ colortex0 ┐
|R |G |B |A |
└8 ┴8 ┴8 ┴8 ┘
 |  |  |  └X
 └[normalized color (RGB)]
```

```
┌ colortex1 ┐
|R |G |B | A|
└16┴16┴16┴16┘
 |  |  |  └[roughness]
 └[color (RGB)]
```

```
┌ colortex2 ┐
|---  R  ---|
└13 13 4 1 1┘
 |  |  | | └["hand" flag]
 |  |  | └["pure light" flag]
 |  |  └[emission]
 |  └[sky light]
 └[block light]
```

```
┌ colortex3 ┐
|R |G |B | A|
└16┴16┴16┴16┘
 |  |  |  |
 └[biased shadow screen space position]
```

```
┌--- lightIndex ----┐
|- data  -|- color -|
└9 9 9 4 1┴ 6  5  5 ┘
 | | | | |  |  |  |
 | | | | |  └[color (GRB)]: 6/5/5
 | | | | └["wide" flag]: 1x1
 | | | └[intensity]
 └[player feet space position]
```
