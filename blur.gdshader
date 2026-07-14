shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform sampler2D aoTexture : source_color;
uniform vec2 textureSize = vec2(1920.0,1080.0);

void fragment()
{
    vec2 texel = 1.0 / vec2(textureSize(aoTexture, 0));

    float center = texture(aoTexture, SCREEN_UV).r;

    float sum = 0.0;
    float weightSum = 0.0;

    const float sigma = 0.15;

    for(int x = -2; x <= 2; x++)
    {
        for(int y = -2; y <= 2; y++)
        {
            vec2 offset = vec2(float(x), float(y)) * texel;

            float sample = texture(aoTexture, SCREEN_UV + offset).r;

            float spatialWeight =
                exp(-(float(x*x + y*y)) / 8.0);

            float rangeWeight =
                exp(-pow(sample - center, 2.0) / sigma);

            float weight = spatialWeight * rangeWeight;

            sum += sample * weight;
            weightSum += weight;
        }
    }

    float blurred = sum / weightSum;

    ALBEDO = vec3(blurred);
}