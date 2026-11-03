#version 440
// GlassEdge: a 1 px ring with top-left light and a faint bottom-right accent reflection.
// Drawn in one pass, with no offscreen layer or mask.
// Compiled to glass-edge.frag.qsb by tools/build-shaders.py.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // item size, pixels
    float radius;   // corner radius, pixels
    float edge;     // peak alpha
    vec4 tint;      // the light's colour, opaque
    vec4 reflection; // the accent reflection, opaque
};

// Signed distance to a rounded rectangle of half size b centred on the origin.
float box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float r = min(radius, 0.5 * min(size.x, size.y));
    float d = box(p - 0.5 * size, 0.5 * size, r);
    // Coverage of the band between the outer edge and 1 px inside it, antialiased.
    float ring = clamp(0.5 - d, 0.0, 1.0) - clamp(-0.5 - d, 0.0, 1.0);
    // Normalise in surface coordinates so even a very wide capsule catches light along its top.
    vec2 direction = qt_TexCoord0 - 0.5;
    direction /= max(length(direction), 0.0001);
    float light = dot(direction, vec2(-0.6, -0.8));
    float specular = pow(max(light, 0.0), 1.5);
    float bounce = 0.18 * pow(max(-light, 0.0), 1.5);
    float coverage = ring * edge * qt_Opacity;
    fragColor = vec4((tint.rgb * specular + reflection.rgb * bounce) * coverage,
                     (specular + bounce) * coverage);
}
