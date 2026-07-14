#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform PushConstants {
    vec2 VIEWPORT_SIZE;
    vec2 padding;
} push_constants;

layout(rgba16f, set = 0, binding = 0) uniform image2D colorImage;
layout(set = 0, binding = 1) uniform sampler2D aoTexture;

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

    if (pixel.x >= int(push_constants.VIEWPORT_SIZE.x) ||
        pixel.y >= int(push_constants.VIEWPORT_SIZE.y))
        return;

    vec2 uv = (vec2(pixel) + vec2(0.5)) / push_constants.VIEWPORT_SIZE;

    float ao = texture(aoTexture, uv).r;

    vec4 color = imageLoad(colorImage, pixel);

    imageStore(colorImage, pixel, vec4(color.rgb * ao, color.a));
}