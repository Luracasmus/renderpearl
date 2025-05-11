# Technical Overview

## Pipeline (outdated)

> X marks the spot... where a write happens (in the buffer corresponding to the line)

### Shadow & Solid Geometry

```
shadow*   :   * ┌> shadow -X┬--*-------------------*->
gtexture  : >-*-┴-----------┼--*-> gbuffers(solid) *
specular  : >-*-SM----------┤  *    ||||           *
normals   : >-*-NORMALS-----┘  *    ||||           *
colortex1 :   *                *    |||└X----------*->
colortex2 :   *                *    ||└X-----------*->
colortex3 :   *                *    |└X------------*->
lightIndex: >-*----------------*----X--------------*->
[Barriers]: [ X                X                   X ]
              |                └> Solid Geometry
              └> Shadow Map Geometry
```

### Deferred Processing

```
indirectGeometry: >-*--┐    ┌----X-*-------------------*-------------*->
indirectSMFacing: >-*-deferred---X-*--┬----------------*-------------*->
deferredLight1  :   *  |           * deferred1-------X-*---┐         *
deferredLight  :   *  |           *  || deferred1_a-X-*--┐|         *
colortex2       : >-*--┴-----------*--┴┼--┘|||         *  ||         *
colortex3       : >-*--------------*---┼---┘||         *  ||         *
lightIndex      : >-*-deferred_a-X-*---┼----┘|         *  ||         *
colortex1       : >-*--------------*---┴-----┴---------*-deferred2-X-*->
[Barriers]      : [ X              X                   X             X ]
                    |              |                   └> Light Buffer Application and Sky Rendering
                    |              └> Shadow Map and Vanilla + Light Index Lighting
                    └> Indirect Dispatch Setup and Light Index Deduplication
```

### Translucent Geometry

```
shadow*   : >-*---------┐                        *
gtexture  : >-*---------┼> gbuffers(translucent) *
specular  : >-*-SM------┤   |                    *
normals   : >-*-NORMALS-┤   |                    *
lightIndex: >-*---------┘   |                    *
colortex1 : >-*-------------X--------------------*->
[Barriers]: [ X                                  X ]
              └> Translucent Geometry
```

### Post-Processing

```
indirectGeometry:   *             *          ┌---X-*--------------*------------*--------------*--------------*->
indirectSMFacing: >-*--┬----------*----------┼---X-*--------------*------------*--------------*--------------*->
dcgBuffer       :   *  |        ┌-*-> composite1-X-*┐             *            *              *              *
colortex1       : >-*-composite-X-*----┴-----------*┴> composite1_a *            *              *              *
tempCol         :   *             *                *           └X-*-composite2-*--------------*----┐         *
colortex0       :   *             *                *              *         |  *              *    |      ┌X-*->
edge            :   *             *                *              *         └X-*-> composite3 *    |      |  *
blendWeight     :   *             *                *              *            *    ^^     └X-*-> composite4 *
areatex         : >-*-------------*----------------*--------------*------------*----┘|        *              *
searchtex       : >-*-------------*----------------*--------------*------------*-----┘        *              *
[Barriers]      : [ X             X                X              X            X              X              X ]
                    |             |                |              |            |              └> SMAA Neighborhood Blending and CAS
                    |             |                |              |            └> SMAA Blend Weight Calculation
                    |             |                |              └> SMAA Edge Detection
                    |             |                └> DCG Application, Color Balance, Saturation, Tone Mapping, and Compass
                    |             └> DCG Analysis
                    └> Fog and VL
```

## Packing & Layout (outdated)

> Remember "When bit-packing fields into a G-Buffer, put highly correlated bits in the Most Significant Bits (MSBs) and noisy data in the Least Significant Bits (LSBs)."

```
┌ colortex0 ┐
|R |G |B |A |
└16┴16┴16┴16┘
 |  |  |  └X
 └[normalized color]: 3x16
```

```
┌ colortex1 ┐
|R |G |B | A|
└16┴16┴16┴16┘
 |  |  |  └[roughness ("hand" flag stored in sign)]: 1x16
 └[hdr color (emission packed in sign bits)]: 3x16
```

```
┌ colortex2 ┐
|R |G |B |A |
└8 ┴8 ┴8 ┴8 ┘
 |  |  |  |
 |  |  └[face normal]: 2x8
 └[texture normal]: 2x8
```

```
┌ colortex3 ┐
|- R -|- G -|
└  8  ┴  8  ┘
   |     └[sky + ambient light level]: 1x8
   └[block light level]: 1x8
```

```
┌ colortex4 ┐
| R | G | B |
└16 ┴16 ┴16 ┘
  |   |   |
  └[Biased distorted shadow screen space position]: 3x16
```

```
┌--- lightIndex ----┐
|- data  -|- color -|
└9 9 9 4 1┴ 6  5  5 ┘
 | | | | |  |  |  |
 | | | | |  └[color (GRB)]: 6/5/5
 | | | | └[wide]: 1x1
 | | | └[brightness]: 1x4
 └[pos]: 3x9
```
