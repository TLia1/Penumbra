#version 440
// Aurora over the near world's horizon: curtains that fold and drift along the arc, fine rays,
// violet at the base turning rose higher up, and a faint glow on the night side below.
// Compiled to aurora.frag.qsb by tools/build-wallpapers.py.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 size;      // item size, scene units
    vec2 center;    // world center, relative to the item
    float radius;   // world radius
    float arcFrom;  // where the aurora starts and ends, radians from the top of the world
    float arcTo;
};

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 d = p - center;
    float h = length(d) - radius;
    float a = atan(d.x, -d.y);
    float u = (a - arcFrom) / (arcTo - arcFrom);
    float s = a * radius;

    float envelope = smoothstep(0.0, 0.22, u) * smoothstep(1.0, 0.7, u);
    float fold = 0.5 + 0.5 * sin(s * 0.011 - time * 0.45 + 1.8 * sin(s * 0.0037 + time * 0.12));
    float ripple = 0.5 + 0.5 * sin(s * 0.029 + time * 0.9 + 2.0 * sin(s * 0.006 - time * 0.3));
    float light = fold * (0.35 + 0.65 * ripple);
    float rays = 0.74 + 0.16 * sin(s * 0.21 + 4.0 * sin(s * 0.012 - time * 0.55)) + 0.1 * sin(s * 0.083 - time * 0.3);

    float top = 150.0 + 130.0 * (0.5 + 0.5 * sin(s * 0.005 + time * 0.2));
    // Curtains thin out well before the top of the item, so its edge never shows.
    float curtain = smoothstep(0.0, 22.0, h) * exp(-max(h, 0.0) / top) * (1.0 - smoothstep(top, top * 2.0, h)) * rays;
    float below = exp(min(h, 0.0) / 40.0) * (1.0 - step(0.0, h)) * 0.35;

    float alpha = 0.55 * envelope * light * (curtain + below) * smoothstep(0.0, 160.0, p.y);
    vec3 color = mix(vec3(0.77, 0.65, 1.0), vec3(0.89, 0.54, 0.75), smoothstep(30.0, 260.0, h));
    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
