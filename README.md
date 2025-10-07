# RenderPearl

![Banner](https://cdn.modrinth.com/data/BrRak9pu/images/9d2f33b85447099c25b6291b680608bc47c1f5e1.png)

RenderPearl is an incredibly lightweight shader pack using the latest Iris features and optional extensions on various graphics drivers, aiming to deliver pleasant visuals with excellent performance on modern hardware.

It is currently **only** tested with up-to-date AMD+Mesa and NVIDIA graphics drivers on Linux. If you want to report a bug or give feedback/suggestions, the best way to do so is by opening an issue on the [GitHub issue tracker](https://github.com/Luracasmus/renderpearl/issues) or leaving a comment on the [PMC page](https://www.planetminecraft.com/mod/luracasmus-s-shaders/) or [CurseForge page](https://www.curseforge.com/minecraft/shaders/renderpearl/comments). I rely heavily on user feedback in bug fixing and design.

<details>
<summary>Trivia</summary>

This project started as a continuation of "Luracasmus Shaders" (which is why you might have seen it called "LS RenderPearl"), but modern versions share little to no code with the original project. The question remains as to whether the same shader pack remains throughout, when all parts are replaced.

The name "RenderPearl" is inspired by the Bedrock Edition [RenderDragon](https://minecraft.fandom.com/wiki/RenderDragon) engine.

</details>

## Features

<details>
<summary>LabPBR 1.3 compliance & material data </summary>

"Yes" indicates support for per-texel data.

| LabPBR 1.3 required component | From resource pack                        | Configurable nonstandard channels | Included/procedural     |
| ----------------------------- | ----------------------------------------- | --------------------------------- | ----------------------- |
| Albedo                        | Yes                                       | No                                | No                      |
| Smoothness                    | Yes, or as linear or perceptual roughness | Yes                               | Yes                     |
| f0/reflectance                | No                                        |                                   | Constant                |
| Normal                        | Yes                                       | No                                | Yes                     |

| LabPBR 1.3 optional component | From resource pack | Included/procedural                    |
| ----------------------------- | ------------------------------ | -------------------------------------- |
| Hardcoded metal               | No                             | No                                     |
| Porosity                      | No                             | No                                     |
| Subsurface scattering         | No                             | Constant, only on translucent geometry |
| Emmissiveness                 | No                             | Yes                                    |
| Ambient occlusion             | Binary, per-block (from model) | Yes                                    |
| Height                        | No                             | No                                     |

</details>

* Smooth, colored real-time shadows and volumetric light using distorted shadow mapping.
* Colored block light with physically based reflections using a light list combined with vanilla lighting and average texture color.
* A wide range of highly optimized post-processing effects, including compute shader ports of [FidelityFX Contrast Adaptive Sharpening](https://gpuopen.com/fidelityfx-cas/), [SMAA](https://www.iryoku.com/smaa/) 1x from [SMAA-MC](https://modrinth.com/shader/smaa-mc), automatic exposure and a variety of tone mapping operators.
* Customizable waves and water opacity.
* Built-in utility features such as light level visualization and a compass overlay.

## Mod & Resource Pack Compatibility

Most built-in PBR information, including light colors, material normals and roughness, are almost entirely procedurally generated and should therefore work with almost any resource pack or mod.

Support for mods that modify the Iris shader pipeline, such as Chunks Fade In, is experimental and may have issues, such as the shader pack failing to compile.

Distant Horizons should be compatible in the sense that everything loads, but the geometry outside the regular render distance will not be visible. Complete support is planned for a future update.

## Requirements

> If you have a decently modern non-macOS device it probably supports everything you need, but you might have to update your Iris and graphics drivers.

* **Iris 1.9.2+** with support for features:
  * `BLOCK_EMISSION_ATTRIBUTE`
  * `COMPUTE_SHADERS`
  * `CUSTOM_IMAGES`
  * `ENTITY_TRANSLUCENT`
  * `SEPARATE_HARDWARE_SAMPLERS`
  * `SSBO`
* **Graphics drivers** with support for **GLSL 4.60.8+**.

## Tuning & The Compatibility Menu

The default configuration and all values selectable with profiles are intended to work on all systems that meet the shader pack's **Requirements**, though you may be able to achieve higher performance and quality by changing some of these options. Beware that some values may cause the shader pack to not compile, in which case you simply have to reset the option. These are usually marked with a red ⚠.

<details>
<summary>Implementation-Limited Options</summary>

> The usable values and effects of these options depend on your graphics drivers.

* **Light List Capacity** is limited by the amound of Local Data Share memory usable per work group on your GPU. Depending on your GPU and graphics drivers, and the features enabled by the 16/8-Bit Types option, you may be able to set this significantly higher than the maximum value selectable with profiles (though there is no reason to do so if the light list isn't being filled completely, usually indicated by lights flickering, as it impacts performance negatively).

* **16/8-Bit Types** uses optional OpenGL/GLSL extension-provided half- and/or quarter-sized data types to reduce register, LDS and VRAM usage. Performance impact varies depending on hardware and drivers, as conversion between types has a cost, but operations with smaller types can be significantly faster.

* **Trinary Min/Max** performs trinary minimum and maximum operations in singular function calls using the optional `AMD_shader_trinary_minmax` OpenGL/GLSL extension, which may allow generation of more optimal instruction sequences. It's recommended to use this whenever possible.

* **32×16-Bit Multiplication** performs multiplication between 32-bit integers and integers in the 16-bit-representable range using special functions provided by the optional `INTEL_shader_integer_functions` OpenGL/GLSL extension, that may be faster than regular 32-bit multiplication operators. It's recommended to use this whenever possible.

* **Immutable Constants** marks all shader variables that can be immutable as constant, possibly enabling better optimizations. This feature is required by the GLSL specification, but still unsupported on some graphics drivers. It's recommended to use it whenever possible.

</details>

## Design & Modding RenderPearl

RenderPearl's source code is intended to be modifiable and re-usable. It's written according to best practice to the best of my ability, but prioritizing performance over readability. If you have any questions about how it works, feel free to contact me on any platform.

Technical information can be found in [DEV.md](/DEV.md).

---

> **This, [the Modrinth page](https://modrinth.com/shader/renderpearl), [the CurseForge page](https://www.curseforge.com/minecraft/shaders/renderpearl) and [the PMC page](https://www.planetminecraft.com/mod/luracasmus-s-shaders/) are the only RenderPearl project pages made by me.** If you want to distribute RenderPearl, or just spread the word of it, I would greatly appreciate if you would link to at least one of them, preferrably Modrinth.
