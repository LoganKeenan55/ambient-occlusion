#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform PushConstants {
    vec2 VIEWPORT_SIZE;
    vec2 padding;
} push_constants;

layout(rgba16f, set = 0, binding = 0) uniform image2D colorImage;
layout(set = 0, binding = 1) uniform sampler2D aoTexture;
layout(set = 0, binding = 2) uniform sampler2D depthTexture;

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

    if (pixel.x >= int(push_constants.VIEWPORT_SIZE.x) ||
        pixel.y >= int(push_constants.VIEWPORT_SIZE.y))
        return;

    vec2 uv = (vec2(pixel) + vec2(0.5)) / push_constants.VIEWPORT_SIZE;
    vec2 texel_size = 1.0 / push_constants.VIEWPORT_SIZE;

    float centerDepth = texture(depthTexture, uv).r;

    const int BLUR_RADIUS = 2; //5x5 kernel
    const float depthThreshold = 0.001;

    float aoSum = 0.0;
    float weightSum = 0.0;

    for (int y = -BLUR_RADIUS; y <= BLUR_RADIUS; y++) {
        for (int x = -BLUR_RADIUS; x <= BLUR_RADIUS; x++) {
            vec2 offset = vec2(float(x), float(y)) * texel_size;
            vec2 sampleUV = uv + offset;

            float sampleDepth = texture(depthTexture, sampleUV).r;
            float depthDiff = abs(sampleDepth - centerDepth);

            //rject samples that are on a different surface
            float weight = (depthDiff < depthThreshold) ? 1.0 : 0.0;

            aoSum += texture(aoTexture, sampleUV).r * weight;
            weightSum += weight;
        }
    }

    float ao = (weightSum > 0.0) ? (aoSum / weightSum) : texture(aoTexture, uv).r;

    vec4 color = imageLoad(colorImage, pixel);
    imageStore(colorImage, pixel, vec4(color.rgb * ao, color.a));
}