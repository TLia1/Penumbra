#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    vec2 pointer;
    float glow;
    vec2 size;
    vec4 tint;
    vec4 light;
};
void main() {
    vec2 p = qt_TexCoord0 * size;
    float r = min(radius, min(size.x, size.y) * .5);
    vec2 q = abs(p - .5 * size) - .5 * size + r;
    float d = min(max(q.x, q.y), 0.) + length(max(q, 0.)) - r;
    float mask = clamp(.5 - d, 0., 1.);
    float wash = .035 * (1. - qt_TexCoord0.y);
    float spot = .12 * glow * exp(-dot(p - pointer, p - pointer) / 7000.);
    fragColor = vec4(light.rgb * wash + tint.rgb * spot, wash + spot) * mask * qt_Opacity;
}
