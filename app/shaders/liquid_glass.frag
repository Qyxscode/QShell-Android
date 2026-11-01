#version 460 core
#include <flutter/runtime_effect.glsl>

// 液态玻璃折射：
// 采样背景纹理，按「到中心的距离」做一个凸透镜式位移——边缘拉伸、
// 中心不变，再叠一层边缘高光，得到透过厚玻璃看背景的观感。

uniform vec2 uSize;      // 控件尺寸（逻辑像素）
uniform float uStrength; // 折射强度（0 = 关闭）
uniform float uRim;      // 边缘高光强度
uniform float uTint;     // 玻璃底色不透明度
uniform vec4 uTintColor; // 玻璃底色
uniform sampler2D uBg;   // 背景（由 ImageFilter.shader 注入）

out vec4 fragColor;

void main() {
    vec2 fragPos = FlutterFragCoord().xy;
    vec2 uv = fragPos / uSize;

    // 归一化到 [-1, 1]，长边对齐
    vec2 c = uv * 2.0 - 1.0;
    float dist = length(c);

    // 凸透镜位移：越靠外偏移越大，中心几乎不动
    vec2 dir = dist > 0.0001 ? c / dist : vec2(0.0);
    float falloff = pow(clamp(dist, 0.0, 1.0), 3.0);
    vec2 offset = -dir * (uStrength * falloff) / uSize;

    vec4 bg = texture(uBg, clamp(uv + offset, vec2(0.0), vec2(1.0)));

    // 边缘高光：贴着轮廓的一圈亮边
    float rim = smoothstep(0.72, 1.0, dist) * uRim;

    vec3 color = mix(bg.rgb, uTintColor.rgb, clamp(uTint, 0.0, 1.0));
    color += rim * uTintColor.rgb;

    fragColor = vec4(color, 1.0);
}
