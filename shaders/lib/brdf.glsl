/*
	Based on:
		https://github.com/bevyengine/bevy/blob/e8b3598ff5e5ec40e8ba84edd5750a1c0e4d4e59/crates/bevy_pbr/src/render/pbr_lighting.wesl
		https://github.com/bevyengine/bevy/blob/e8b3598ff5e5ec40e8ba84edd5750a1c0e4d4e59/crates/bevy_pbr/src/render/pbr_functions.wesl

	MIT License

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/
/*
	Based on (modified by Luracasmus): https://github.com/google/filament/blob/9169148fff3be2129091f7920e506700b81905e5/docs/Filament.md.html

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright 2023 The Android Open Source Project

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

uniform sampler2D dfgLut;

// F_ab.x + F_ab.y
float16_t f_ab_sum(float16_t roughness, float16_t n_dot_v) {
	immut float16_t perceptual_roughness = sqrt(roughness);

	return dot(
		f16vec2(textureLod(dfgLut, f16vec2(n_dot_v, perceptual_roughness), 0.0).rg),
		f16vec2(1.0)
	);
}

// Properties of a surface receiving light.
struct BrdfReceiver {
	f16vec3 normal;
	f16vec3 obs_to_rec_dir; // Receiver direction from observer.
	float16_t roughness;
	f16vec3 f0;
	float16_t n_dot_v;
	f16vec3 specular_multiplier;
};

BrdfReceiver create_brdf_rec(
	f16vec3 normal,
	f16vec3 obs_to_rec_dir, // Receiver direction from observer.
	float16_t roughness,
	float16_t f0_in,
	bool is_metal,
	f16vec3 color,
	f16vec3 rcp_color
) {
	// Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The Order: 1886".
	immut float16_t n_dot_v = max(dot(normal, -obs_to_rec_dir), float16_t(0.0001));

	immut f16vec3 f0 = is_metal ? color : f16vec3(f0_in);

	immut f16vec3 specular_multiplier = (float16_t(1.0) + (f0 / f_ab_sum(roughness, n_dot_v) - f0)) * rcp_color;

	return BrdfReceiver(
		normal,
		obs_to_rec_dir,
		roughness,
		f0,
		n_dot_v,
		specular_multiplier
	);
}

uvec4 pack_brdf_rec(BrdfReceiver rec) {
	return uvec4(
		packFloat2x16(octa_encode(rec.normal)),
		packFloat2x16(octa_encode(rec.obs_to_rec_dir)),
		packUnorm4x8(f16vec4(rec.roughness, rec.f0)),
		packUnorm4x8(f16vec4(rec.n_dot_v, rec.specular_multiplier))
	);
}

BrdfReceiver sg_broadcast_brdf_rec(BrdfReceiver rec) {
	return BrdfReceiver(
		f16vec3(subgroupBroadcastFirst(rec.normal)),
		f16vec3(subgroupBroadcastFirst(rec.obs_to_rec_dir)),
		float16_t(subgroupBroadcastFirst(rec.roughness)),
		f16vec3(subgroupBroadcastFirst(rec.f0)),
		float16_t(subgroupBroadcastFirst(rec.n_dot_v)),
		f16vec3(subgroupBroadcastFirst(rec.specular_multiplier))
	);
}

#ifdef FLOAT16
	// fp16 adaptation, see https://google.github.io/filament/Filament.html#listing_speculardfp16
	float16_t d_ggx_fp16(float16_t roughness, float16_t n_dot_h, f16vec3 normal, f16vec3 half_dir) {
		const float16_t f16_max = float16_t(65504.0);

		immut f16vec3 n_x_h = cross(normal, half_dir);
		immut float16_t a = n_dot_h * roughness;
		immut float16_t k = roughness / fma(a, a, dot(n_x_h, n_x_h));
		immut float16_t d = k * k * float16_t(1.0/PI);
		return min(d, f16_max);
	}
#else
	float d_ggx_fp32(float roughness, float n_dot_h) {
		immut float a = n_dot_h * roughness;
		immut float k = roughness / (1.0 - n_dot_h * n_dot_h + a * a);
		immut float d = k * k * (1.0/PI);
		return d;
	}
#endif

float16_t v_smith_ggx_correlated(float16_t roughness, float16_t n_dot_v, float16_t n_dot_l) {
	immut float16_t a_2 = roughness * roughness;

	immut float16_t lambda_v_l_sum = dot(
		f16vec2(n_dot_l, n_dot_v),
		sqrt(f16vec2(n_dot_v, n_dot_l) * f16vec2(n_dot_v, n_dot_l) * (float16_t(1.0) - a_2) + a_2)
	);

	return float16_t(0.5) / lambda_v_l_sum;
	// immut float16_t rcp_ggx_v_l_sum = dot(float16_t(1.0) / f16vec2(n_dot_l, n_dot_v), inversesqrt(f16vec2(n_dot_v, n_dot_l) * f16vec2(n_dot_v, n_dot_l) * (float16_t(1.0) - a_2) + a_2));
	// return float16_t(0.5) * rcp_ggx_v_l_sum;
}

float16_t f_schlick(float16_t f0, float16_t f90, float16_t v_dot_h) {
	return fma(pow(float16_t(1.0) - v_dot_h, float16_t(5.0)), f90 - f0, f0);
}

f16vec3 f_schlick(f16vec3 f0, float16_t f90, float16_t v_dot_h) {
	return fma(pow(float16_t(1.0) - v_dot_h, float16_t(5.0)).xxx, f90 - f0, f0);
}

f16vec3 fresnel(f16vec3 f0, float16_t l_dot_h) {
	immut float16_t f90 = saturate(dot(f0, f16vec3(50.0 * 0.33)));
	return f_schlick(f0, f90, l_dot_h);
}

// Diffuse BRDF.
float16_t fd_burley(float16_t roughness, float16_t n_dot_v, float16_t n_dot_l, float16_t l_dot_h) {
	immut float16_t f90 = float16_t(0.5) + float16_t(2.0) * roughness * l_dot_h * l_dot_h;
	immut float16_t scatter_l = f_schlick(float16_t(1.0), f90, n_dot_l);
	immut float16_t scatter_v = f_schlick(float16_t(1.0), f90, n_dot_v);
	return scatter_l * scatter_v * float16_t(1.0/PI);
}

// Computes the sum of diffuse and specular reflected light by `rec`, not multiplied by its color.
//
// All inputs must be in aligned spaces.
f16vec3 brdf(
	BrdfReceiver rec,
	float16_t n_dot_l, // Receiver normal dot `rec_to_lig_dir`. Must be in [0, 1].
	f16vec3 rec_to_lig_dir // Light direction from receiver.
) {
	#ifdef FLOAT16
		immut f16vec3 half_dir = normalize(rec_to_lig_dir - rec.obs_to_rec_dir); // Halfway between light and observer direction from receiver.

		immut float16_t n_dot_h = saturate(dot(rec.normal, half_dir));
		immut float16_t l_dot_h = saturate(dot(rec_to_lig_dir, half_dir));

		immut float16_t d = d_ggx_fp16(rec.roughness, n_dot_h, rec.normal, half_dir);
	#else
		// Save one multiplication by `rcp_half_vec_len`.
		immut f16vec3 half_vec = rec_to_lig_dir - rec.obs_to_rec_dir;
		immut float16_t rcp_half_vec_len = inversesqrt(dot(half_vec, half_vec));

		immut float16_t n_dot_h = saturate(dot(rec.normal, half_vec) * rcp_half_vec_len);
		immut float16_t l_dot_h = saturate(dot(rec_to_lig_dir, half_vec) * rcp_half_vec_len);

		immut float16_t d = d_ggx_fp32(rec.roughness, n_dot_h);
	#endif

	immut float16_t v = v_smith_ggx_correlated(rec.roughness, rec.n_dot_v, n_dot_l);
	immut f16vec3 f = fresnel(rec.f0, l_dot_h);

	immut f16vec3 specular = (d * v) * f; // Distribution * visibility * Fresnel term.

	return n_dot_l * (
		fd_burley(rec.roughness, rec.n_dot_v, float16_t(n_dot_l), l_dot_h) +
		specular * rec.specular_multiplier // TODO: Is this correct for metals?
	);
}
