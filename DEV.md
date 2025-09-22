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
lightList : >-*----------*----------┼X-----*->
handLight : >-*----------*----------X------*->
[Barriers]: [ X          X                 X ]
              |          └> Solid geometry
              └> Shadow geometry
```

### Deferred Processing

```
lightList : >-*-deferred-X-*--┬----------*->
colortex1 : >-*------------*-deferred1-X-*->
colortex2 : >-*------------*--┘||        *
handLight : >-*------------*---┘|        *
shadow*   : >-*------------*----┘        *
[Barriers]: [ X            X             X ]
              |            └> Deferred lighting, and sky
              └> Light list deduplication
```

### Translucent Geometry

```
handLight : >-*----┐                    *
lightList : >-*---┐|                    *
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
 └[color (RGB)] (unorm)
```

```
┌ colortex1 ┐
|R |G |B |A |
└16┴16┴16┴16┘
 |  |  |  └[AO] (float)
 └[color (RGB)] (float)
```

```
┌ colortex2 -----------------┐
|R    |G        |B     |A    |
└16 16┴15 15 1 1┴8 8 16┴16 16┘
 |  |  |  |  | | | | |  |  |
 |  |  |  |  | | | | └[biased shadow screen space position] (unorm)
 |  |  |  |  | | | └[subsurface scattering] (unorm)
 |  |  |  |  | | └[roughness] (unorm)
 |  |  |  |  | └["hand" flag] (bool)
 |  |  |  |  └["pure light" flag] (bool)
 |  |  |  └[sky light] (unorm)
 |  |  └[block light] (unorm)
 |  └[octahedron encoded face normal] (float)
 └[octahedron encoded texture normal] (float)
```

```
┌ lightList ----┐
|data     |color|
└9 9 9 4 1┴6 5 5┘
 | | | | | | | |
 | | | | | └[color (GRB)] (unorm)
 | | | | └["wide" flag] (bool)
 | | | └[intensity] (uint)
 └[player feet space position] (uint)
```

### Proposed

```
┌ colortex1 ┐
|R |G |B |A |
└16┴16┴16┴16┘
 |  |  |  └[block light] (float)
 └[color (RGB)] (float)
```

```
┌ colortex2 ----------------┐
|R    |G      |B      |A    |
└16 16┴16 13 3┴8 8 8 8┴31 1 ┘
 |  |  |  |  | | | | | |  └["hand" flag] (bool)
 |  |  |  |  | | | | | └[biased shadow screen space position Z] (unsigned float)
 |  |  |  |  | | | | └[f0/flag enum] (uint)
 |  |  |  |  | | | └[emissiveness] (unorm)
 |  |  |  |  | | └[subsurface scattering] (unorm)
 |  |  |  |  | └[roughness] (unorm)
 |  |  |  |  └[AO direction) (uint)
 |  |  |  └[AO] (unorm)
 |  |  └[sky light] (float)
 |  └[octahedron encoded face normal] (float)
 └[octahedron encoded texture normal] (float)
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
└32┴32------┘
 |  |
 └[biased shadow screen space position XY] (float)
```
