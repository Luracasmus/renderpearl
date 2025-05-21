# RenderPearl

![Banner](https://cdn.modrinth.com/data/BrRak9pu/images/9d2f33b85447099c25b6291b680608bc47c1f5e1.png)

RenderPearl is an incredibly lightweight shader pack using the latest [Iris](https://irisshaders.dev/) and [GLSL](https://www.wikiwand.com/en/OpenGL_Shading_Language) features, aiming to deliver pleasant graphics with excellent performance on modern hardware

It is currently **only** tested with NVIDIA graphics drivers. If you want to report a bug or give feedback/suggestions, the easiest way to do so is by leaving a comment on the [PMC page](https://www.planetminecraft.com/mod/luracasmus-s-shaders/). I rely heavily on user feedback in bug fixing and design

<details>
<summary>Trivia</summary>

This project started as a continuation of "Luracasmus Shaders" (which is why you might have seen it called "LS RenderPearl"), but modern versions share little to no code with the original project. The question remains as to whether the same shader pack remains throughout, when all parts are replaced

The name "RenderPearl" is inspired by the Bedrock Edition [RenderDragon](https://minecraft.fandom.com/wiki/RenderDragon) engine

</details>

## Features

* Detailed, colored real-time shadows and volumetric light using simple shadow mapping and BRDF reflections
* Colored light index-based block light with BRDF reflections
* A wide range of almost zero-cost post-processing effects, including [FidelityFX Contrast Adaptive Sharpening](https://gpuopen.com/fidelityfx-cas/) and a variety of tone mapping operators
  * [SMAA](https://www.iryoku.com/smaa/) 1x
    * Lightweight high-quality anti-aliasing preserving sharpness and clarity
    * Implementation based on [SMAA-MC](https://modrinth.com/shader/smaa-mc)
  * Dynamic Color Grading automatically adjusts exposure, black point and color balance to improve visibility and more fully utilize the display's limited range 
* Customizable Vanilla Ambient Occlusion
* Optionally emissive Redstone, Lapis and Emerald Blocks
* Customizable waves and water opacity
* Specular and normal map support as well as automatically generated normals and roughness values
* Built-in utility features such as light level visualization and a compass overlay
* And more...

## Requirements

* **[Iris](https://irisshaders.dev/) 1.8+** with [features](https://shaders.properties/current/reference/shadersproperties/flags/):
  * `BLOCK_EMISSION_ATTRIBUTE`
  * `COMPUTE_SHADERS`
  * `CUSTOM_IMAGES`
  * `ENTITY_TRANSLUCENT`
  * `SEPARATE_HARDWARE_SAMPLERS`
  * `SSBO`
* **[GLSL](https://www.wikiwand.com/en/OpenGL_Shading_Language) 4.60.8+**

> This may require updating your graphics drivers

## Tuning & The Compatibility Menu

The default configuration and all values selectable with profiles are intended to work on all systems that meet the shader pack's **Requirements**, though you may be able to achieve higher performance and quality by changing some of these options. Beware that some values may cause the shader pack to not compile, in which case you simply have to reset the option. These are usually marked with a ⚠

<details>
<summary>Implementation-Limited Options</summary>

> The usable values and effects of these options depend on your OpenGL and GLSL implementations

* **Index Size** is limited by the amound of Local Data Share memory usable per work group on your GPU. Depending on your GPU and graphics drivers, and the features enabled by the 16/8-Bit Types option, you may be able to set this significantly higher than the maximum value selectable with profiles (though there is no reason to do so if the index isn't being filled completely, usually indicated by lights flickering, as it impacts performance negatively)

* **16/8-Bit Types** uses optional OpenGL extension-provided half- and/or quarter-sized data types to reduce register, LDS and VRAM usage. Performance impact varies depending on hardware and drivers, as conversion between types has a cost, but operations with smaller types can be significantly faster

* **Trinary Min/Max** performs trinary minimum and maximum operations in singular function calls using the optional `AMD_shader_trinary_minmax` OpenGL extension, which may allow generation of more optimal instruction sequences. It's recommended to use this whenever possible

* **32×16-Bit Multiplication** performs multiplication between 32-bit integers and integers in the 16-bit-representable range using special functions provided by the optional `INTEL_shader_integer_functions` OpenGL extension, that may be faster than regular 32-bit multiplication operators. It's recommended to use this whenever possible

* **Immutable Constants** marks all shader variables that can be immutable as constant, possibly enabling better optimizations. This feature is required by the GLSL specification, but still unsupported on some graphics drivers. It's recommended to use it whenever possible

</details>

## Design & Modding RenderPearl

RenderPearl's source code is intended to be modifiable and re-usable. It's written according to best practice to the best of my ability, but prioritizing performance over readability. If you have any questions about how it works, feel free to contact me on any platform

Technical information can be found in `/shaders/prelude/config.glsl` or `/shaders/lib/config.glsl` in modern RenderPearl

* Explanation of the Indexed Block Light system based on `v2.2.0-beta.3`: [GitHub Gist](https://gist.github.com/Luracasmus/2278519efd02d765060ebd8083af9fa0)
* Extension support and compatibility prelude used in RenderPearl: [GitHub Gist](https://gist.github.com/Luracasmus/ff78f1998a5a440899e1904fa23cc9c6)

---

> **This and [the PMC page](https://www.planetminecraft.com/mod/luracasmus-s-shaders/) are the only RenderPearl pages made by me.** If you want to distribute RenderPearl, or just spread the word of it, I would greatly appreciate if you would link to at least one of them (preferrably Modrinth)
