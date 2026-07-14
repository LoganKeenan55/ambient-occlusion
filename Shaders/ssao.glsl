#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform PushConstants {
	vec2 VIEWPORT_SIZE;
	vec2 padding;
} push_constants;

layout(std140, set = 0, binding = 3) uniform CameraData {
	mat4 PROJECTION_MATRIX;
	mat4 INV_PROJECTION_MATRIX;
} camera;

layout(r16f, set = 0, binding = 0) uniform image2D aoImage;

layout(set = 0, binding = 1) uniform sampler2D depthTexture;

layout(set = 0, binding = 2) uniform sampler2D noiseTexture;

layout(set = 0, binding = 4) uniform sampler2D normalTexture;

void main(){
	vec3 normal = texture(normalTexture, SCREEN_UV).xyz;
	normal = normal * 2.0 - 1.0;
	normal = normalize(normal);
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

	if(pixel.x >= int(push_constants.VIEWPORT_SIZE.x) ||
		pixel.y >= int(push_constants.VIEWPORT_SIZE.y))
		return;

	vec2 SCREEN_UV = (vec2(pixel) + vec2(0.5)) / push_constants.VIEWPORT_SIZE;

	//depth at current fragment
	float depth = texture(depthTexture, SCREEN_UV).r;

	//convert SCREEN_UV from 0,1 to clip space -1,-1
	vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);

	//get view space from inverting proj matrix from clip space
	vec4 view = camera.INV_PROJECTION_MATRIX * clip;

	//perspective divide
	view /= view.w;

	//in view space camera is always at 0,0,0

	const int SAMPLE_COUNT = 20;

	const vec3 samples[SAMPLE_COUNT] = vec3[](
		vec3(0.53,-0.39,-0.97),
		vec3(0.42,-0.9,0.51),
		vec3(0.74,-0.04,-0.29),
		vec3(-0.7,0.35,0.06),
		vec3(0.64,-0.53,-0.73),
		vec3(-0.19,-0.71,-0.7),
		vec3(-0.53,0.3,0.74),
		vec3(-0.39,0.3,0.77),
		vec3(-0.77,-0.24,1),
		vec3(0.58,-0.92,0.5),
		vec3(0.63,-0.39,0.75),
		vec3(-0.12,0.92,-0.74),
		vec3(-0.17,-0.68,0.46),
		vec3(-0.5,0.07,0.01),
		vec3(0.39,-0.32,0.14),
		vec3(0.99,0.86,0.87),
		vec3(0.38,0.93,0.58),
		vec3(0.24,-0.65,-0.32),
		vec3(0.56,0.49,-0.13),
		vec3(0.44,-0.03,-0.57)
	);

	vec3 fragmentPos = view.xyz;

	float occlusion = 0.0;

	const float radius = 0.1;

	vec2 noiseScale = push_constants.VIEWPORT_SIZE / 4.0;

	ivec2 texel = ivec2(mod(floor(SCREEN_UV * push_constants.VIEWPORT_SIZE), 4.0));

    vec2 noiseVec = texelFetch(
            noiseTexture,
            texel,
            0
        ).xy;

	float noiseAngle = atan(noiseVec.y, noiseVec.x);

	mat2 rotationMatrix = mat2(
		vec2(cos(noiseAngle), sin(noiseAngle)),
		vec2(-sin(noiseAngle), cos(noiseAngle))
	);

	for(int i = 0; i < SAMPLE_COUNT; i++){

		vec3 sampleOffset = TBN * normalize(samples[i]);
		sampleOffset *= radius;

		vec3 samplePos = fragmentPos + sampleOffset;

		vec3 randomVec = normalize(vec3(noiseVec * 2.0 - 1.0, 0.0));

		vec3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
		vec3 bitangent = cross(normal, tangent);

		mat3 TBN = mat3(tangent, bitangent, normal);

		//position near our fragment
		vec3 samplePos = fragmentPos + sampleOffset;

		//go back to clipspace
		vec4 clipPos = camera.PROJECTION_MATRIX * vec4(samplePos, 1.0);

        float invW = 1.0 / clipPos.w;

        vec2 offsetUV = clipPos.xy * invW;
        offsetUV = offsetUV * 0.5 + 0.5;

    

		//get depth of sample
		float sampleDepth = texture(depthTexture, offsetUV).r;
		//go back again to clip space
		vec4 sampleClip = vec4(offsetUV * 2.0 - 1.0, sampleDepth, 1.0);

		//view space
		vec4 sampleView = camera.INV_PROJECTION_MATRIX * sampleClip;

		//perspective divide
		sampleView /= sampleView.w;

		//NOW we have sampleView.xyz which is geometry at that sampled screen location

		//distance from fragment we are shading and geometry
		float rangeCheck = smoothstep(
			0.0,
			1.0,
			radius / abs(fragmentPos.z - sampleView.z)
		);

		//is the real geometry closer to the camera than my imaginary sample? If yes sample is blocked occlusion = 1;
		occlusion += (sampleView.z > samplePos.z ? 1.0 : 0.0) * rangeCheck;
        
	}

    occlusion /= float(SAMPLE_COUNT);

	float ao = 1.0 - occlusion;

    imageStore(
        aoImage,
        pixel,
        vec4(ao, 0.0, 0.0, 1.0)
    );
}