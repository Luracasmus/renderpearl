# Technical Overview

## Pipeline

> X marks the spot... where a write happens (in the buffer corresponding to the line)

### Shadow & Solid Geometry

```
shadow*   : >-*-shadow-X-*--┬--------------*->
gtexture  : >-*--┴-------*-gbuffers(solid) *
specular  : >-*----------*--┘|      ||||   *
normals   : >-*----------*---┘      ||||   *
colortex1 :   *          *          |||└X--*->
colortex2 :   *          *          ||└X---*->
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
lightIndex      : >-*-deferred_a-X-*--┘||              *
handLight       : >-*--------------*---┘|              *
colortex2       : >-*--------------*----┘              *
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

> Remember "When bit-packing fields into a G-Buffer, put highly correlated bits in the Most Significant Bits (MSBs) and noisy data in the Least Significant Bits (LSBs)." ([AMD RDNA Performance Guide](https://gpuopen.com/learn/rdna-performance-guide/))

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
 |  |  |  └[AO]
 └[color (RGB)]
```

```
┌ colortex2 -----------------┐
|R    |G        |B     |A    |
└16 16┴15 15 1 1┴8 8 16┴16 16┘
 |  |  |  |  | | | | |  |  |
 |  |  |  |  | | | | └[biased shadow screen space position]
 |  |  |  |  | | | └[subsurface scattering]
 |  |  |  |  | | └[roughness]
 |  |  |  |  | └["hand" flag]
 |  |  |  |  └["pure light" flag]
 |  |  |  └[sky light]
 |  |  └[block light]
 |  └[octahedron encoded face normal]
 └[octahedron encoded texture normal]
```

```
┌ lightIndex -----┐
|data     |color  |
└9 9 9 4 1┴6  5  5┘
 | | | | | |  |  |
 | | | | | └[color (GRB)]
 | | | | └["wide" flag]
 | | | └[intensity]
 └[player feet space position]
```

### Proposed

```
┌ colortex2 --------------┐
|R    |G    |B      |A    |
└16 16┴16 16┴8 8 8 8┴31 1 ┘
 |  |  |  |  | | | | |  └["hand" flag]
 |  |  |  |  | | | | └[biased shadow screen space position Z]
 |  |  |  |  | | | └[f0/flag enum]
 |  |  |  |  | | └[emissiveness]
 |  |  |  |  | └[subsurface scattering]
 |  |  |  |  └[roughness]
 |  |  |  └[sky light]
 |  |  └[block light]
 |  └[octahedron encoded face normal]
 └[octahedron encoded texture normal]
```

```
┌ f0/flag enum ┐
[0, 229] - f0
230      - "pure light" flag
231      - "metal" flag
232      - "water" flag
```

```
┌ colortex3 ┐
|R |G       |
└16┴16------┘
 |  |
 └[biased shadow screen space position XY]
```
