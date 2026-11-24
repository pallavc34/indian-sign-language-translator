// Re-tones the dermal material in the shader so Saniya reads as fair-skinned.
// Doing it in the fragment shader keeps load time at zero and avoids a 2K
// canvas readback on phones. The dress and hair use other materials.
export function fairSkin(THREE, avatar, { gamma = 0.56, desat = 0.12, warm = 0.03 } = {}) {
  const seen = new Set();
  avatar.traverse((object) => {
    if (!object.isMesh) return;
    const materials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    for (const material of materials) {
      if (!material || !/Skin/i.test(material.name || '') || seen.has(material)) {
        continue;
      }
      seen.add(material);
      material.onBeforeCompile = (shader) => {
        shader.fragmentShader = shader.fragmentShader.replace(
          '#include <map_fragment>',
          `#include <map_fragment>
          diffuseColor.rgb = pow(diffuseColor.rgb, vec3(${gamma.toFixed(3)}));
          float _fairLuma = dot(diffuseColor.rgb, vec3(0.2126, 0.7152, 0.0722));
          diffuseColor.rgb = mix(vec3(_fairLuma), diffuseColor.rgb, ${(1 - desat).toFixed(3)});
          diffuseColor.rgb *= vec3(${(1 + warm).toFixed(3)}, 1.0, ${(1 - warm).toFixed(3)});
          // A light unsharp mask keeps the 2K atlas crisp at phone density.
          vec2 _texel = vec2(1.0 / 2048.0);
          vec3 _blur = (
            texture2D(map, vMapUv + vec2(_texel.x, 0.0)).rgb +
            texture2D(map, vMapUv - vec2(_texel.x, 0.0)).rgb +
            texture2D(map, vMapUv + vec2(0.0, _texel.y)).rgb +
            texture2D(map, vMapUv - vec2(0.0, _texel.y)).rgb
          ) * 0.25;
          diffuseColor.rgb = clamp(diffuseColor.rgb + (diffuseColor.rgb - _blur) * 0.35, 0.0, 1.0);`,
        );
      };
      material.needsUpdate = true;
    }
  });
}
