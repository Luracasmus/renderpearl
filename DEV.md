# Technical Overview

## Pipeline

*Outdated!*

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

> "When bit-packing fields into a G-Buffer, put highly correlated bits in the Most Significant Bits (MSBs) and noisy data in the Least Significant Bits (LSBs)." ([AMD RDNA Performance Guide](https://gpuopen.com/learn/rdna-performance-guide/))

Component descriptions (like "RGB") are in the order they would be packed. The first component is packed in the lowest bits, and the last in the highest.

Most significant <-> Least significant

```
┌ colortex0 ┐
|A |B |G |R |
└8 ┴8 ┴8 ┴8 ┘
 |  |  |  |
 |  └[color (RGB)] (unorm)
 └X
```

```
┌ colortex1 ┐
|A |B |G |R |
└16┴16┴16┴16┘
 |  |  |  |
 |  └[color (RGB)] (float)
 └[block light] (float)
```

```
┌ colortex2 ---------------┐
|A    |B        |G      |R |
└16 16┴1 3 13 15┴8 8 8 8┴32┘
 |  |  | | |  |  | | | | └[shadow distortion] (float)
 |  |  | | |  |  | | | └[roughness] (unorm)
 |  |  | | |  |  | | └[subsurface scattering] (unorm)
 |  |  | | |  |  | └[emissiveness] (unorm)
 |  |  | | |  |  └[f0 (enum)] (uint)
 |  |  | | |  └[sky light] (ufloat)
 |  |  | | └[AO] (unorm)
 |  |  | └[AO direction in 2D across the face (enum)] (uint)
 |  |  └["hand" flag] (bool)
 |  └[octahedron encoded texture normal (XY)] (snorm)
 └[octahedron encoded face normal (XY)] (snorm)
```
> In the nether, the ABG components above are shifted to BGR and the A component left uninitialized.

```
┌ f0 (enum) ┐
[0, 229] - f0
230      - "pure light" flag
231      - "metal" flag
232      - "water" flag // TODO: This should be handled in forward.
```

```
┌ lightList ----┐
|data     |color|
└1 4 9 9 9┴5 5 6┘
 | | | | | | | |
 | | | | | └[color (GRB)] (unorm)
 | | └[player feet space position (XYZ)] (uint)
 | └[intensity] (uint)
 └["wide" flag] (bool)
```

## Code

### Standard variable names for positions

* `texel` - Texel space.
* `coord` - Screen space XY.
* `depth` - Screen space Z.
* `screen` - Screen space XYZ.
* `ndc` - NDC space.
* `clip` - Clip space.
* `view` - View space.
* `pe` - Player eye space.
* `pf` - Player feet space.
* `world` - World space.
* `model` - Model space.

> See the [shaderLABS coordinate space cheat sheet](https://shaderlabs.org/images/5/5a/Space_conversion_cheat_sheet.png).

### Prefixes

* `n_` - Normalized.
* `abs_` - Absolute value.
