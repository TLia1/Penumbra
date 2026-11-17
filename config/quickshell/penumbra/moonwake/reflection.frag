#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
};

void main() {
    vec2 uv = qt_TexCoord0;
    // Compress the distance between crests as the lake recedes to the far bank.
    float distanceFromShore = sqrt(uv.y + 0.015);
    float across = uv.x - 0.724;
    float sway = sin(13.0 * uv.y - 0.55 * time) + 0.45 * sin(26.0 * uv.y + 0.7 * time);
    across += distanceFromShore * 0.012 * sway;
    float breadth = 0.016 + distanceFromShore * 0.059;
    float lane = exp(-across * across / (breadth * breadth));

    // Moving crests catch light in broken horizontal strokes.
    float winding = 0.55 * sin(40.0 * uv.x + 9.0 * uv.y - time);
    float phase = 167.0 * distanceFromShore - 1.85 * time + winding;
    float crest = smoothstep(0.75, 0.995, cos(phase));
    float broken = sin(158.0 * uv.x + 43.0 * uv.y + 1.1 * time)
                 + sin(83.0 * uv.x - 71.0 * uv.y - 0.9 * time);
    float strokes = crest * smoothstep(-0.65, 0.9, broken);
    float light = lane * strokes * 0.23;

    float glints = smoothstep(0.85, 1.0, cos(1.57 * phase + broken))
                 * smoothstep(0.76, 0.99, sin(430.0 * uv.x + 2.4 * time + phase));
    float silver = sqrt(lane) * glints * 0.045;
    float alpha = min(0.9, light + silver) * smoothstep(0.0, 0.027, uv.y) * qt_Opacity;
    vec3 tint = mix(vec3(0.92, 0.72, 0.79), vec3(1.0, 0.92, 0.88), silver / (light + silver + 0.001));
    fragColor = vec4(tint * alpha, alpha);
}
