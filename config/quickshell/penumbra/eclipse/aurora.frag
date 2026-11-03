#version 440
// Aurora over the near world's horizon: curtains that fold and drift along the arc, fine rays,
// violet at the base turning rose higher up, and a faint glow on the night side below.
// Compiled to aurora.frag.qsb by tools/build-shaders.py or tools/build-wallpapers.py.
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
    float bass;
    float mids;
    float treble;
    float audioActive;
    vec4 sceneTint;
    vec4 bandsLow;  // the eight Cava bands, low to high
    vec4 bandsHigh;
    float ceiling;  // item y where the ambient curtains fade out
};

float bandAt(int i) {
    return i < 4 ? bandsLow[i] : bandsHigh[i - 4];
}

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
    float rays = 0.74 + 0.16 * sin(s * 0.21 + 4.0 * sin(s * 0.012 - time * 0.55)) + 0.1 * sin(s * 0.083 - time * 0.3);

    float top = 150.0 + 130.0 * (0.5 + 0.5 * sin(s * 0.005 + time * 0.2));
    float strength = 1.0;
    float fade = smoothstep(ceiling, ceiling + 160.0, p.y);
    if (audioActive > 0.5) {
        // Replace the timed drift with spectrum-driven folds, rays and height. Silence
        // settles to a low, faint rim; bass beats lift the whole horizon, while each of the
        // eight bands shapes its own stretch. No motion here is driven by elapsed time.
        // The spectrum spans the whole visible arc, which runs off-screen at both ends.
        envelope = smoothstep(-0.05, 0.05, u) * smoothstep(1.05, 0.92, u);
        float band = clamp(u, 0.0, 1.0) * 7.0;
        int i = int(floor(band));
        float local = mix(bandAt(i), bandAt(min(i + 1, 7)), fract(band));
        float level = (dot(bandsLow, vec4(1.0)) + dot(bandsHigh, vec4(1.0))) / 8.0;
        // Share some overall loudness and lift the naturally quieter treble so no stretch
        // of the horizon goes dark while the rest is lit.
        float energy = pow(clamp(mix(local, level, 0.3) * (1.0 + 0.6 * u), 0.0, 1.0), 0.75);
        fold = 0.5 + 0.5 * sin(s * 0.011 - bass * 2.5 + 1.8 * sin(s * 0.0037 + mids * 2.0));
        ripple = 0.5 + 0.5 * sin(s * 0.029 + mids * 3.0 + 2.0 * sin(s * 0.006 - treble * 2.0));
        rays = 0.74 + 0.16 * sin(s * 0.21 + 4.0 * sin(s * 0.012 - treble * 2.5))
            + 0.1 * sin(s * 0.083 - mids * 2.0);
        top = 50.0 + 340.0 * energy + 80.0 * bass;
        strength = 0.15 + 2.4 * energy + 0.4 * bass;
        // Folds only modulate the brightness here instead of cutting gaps into it.
        fold = 0.6 + 0.4 * fold * (0.5 + 0.5 * ripple);
        ripple = 1.0;
        // The item is tall enough for the highest curtains, so no flat ceiling is needed.
        fade = 1.0;
    }
    float light = fold * (0.35 + 0.65 * ripple);
    // Curtains thin out well before the top of the item, so its edge never shows.
    float curtain = smoothstep(0.0, 22.0, h) * exp(-max(h, 0.0) / top) * (1.0 - smoothstep(top, top * 2.0, h)) * rays;
    float below = exp(min(h, 0.0) / 40.0) * (1.0 - step(0.0, h)) * 0.35;

    float alpha = 0.55 * envelope * light * (curtain + below) * fade;
    alpha = min(0.9, alpha * strength);
    vec3 color = mix(sceneTint.rgb, mix(sceneTint.rgb, vec3(1.0), 0.22), smoothstep(30.0, 260.0, h));
    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
