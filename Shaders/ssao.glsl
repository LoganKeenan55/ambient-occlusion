//Crytek SSAO 
//~.80ms cost on rtx 2070
#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform PushConstants {
	vec2 VIEWPORT_SIZE;
	float radius;
	float padding;
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
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

	if (pixel.x >= int(push_constants.VIEWPORT_SIZE.x) || pixel.y >= int(push_constants.VIEWPORT_SIZE.y))
		return;

	vec2 SCREEN_UV = (vec2(pixel) + vec2(0.5)) / push_constants.VIEWPORT_SIZE;

	float depth = texture(depthTexture, SCREEN_UV).r;

	//convert SCREEN_UV from 0,1 to clip space -1,-1
	vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);

	//get view space from inverting proj matrix from clip space
	vec4 view = camera.INV_PROJECTION_MATRIX * clip;

	//perspective divide
	view /= view.w;

	const int SAMPLE_COUNT = 16;

	const vec3 samples[SAMPLE_COUNT] = vec3[](
		vec3(-0.08,-0.04,0.04),
		vec3(0.05,0.06,0.07),
		vec3(-0.04,-0.08,0.07),
		vec3(0.07,0.04,0.11),
		vec3(-0.1,0.11,0.02),
		vec3(-0.13,0.1,0.1),
		vec3(0.11,-0.07,0.19),
		vec3(0.19,0.04,0.19),
		vec3(0.14,-0.04,0.29),
		vec3(0.25,-0.26,0.13),
		vec3(0.38,0.17,0.18),
		vec3(-0.52,-0.02,0.05),
		vec3(-0.45,-0.24,0.33),
		vec3(-0.56,0.12,0.4),
		vec3(0.06,0.65,0.44),
		vec3(-0.6,-0.17,0.64)

	);

	vec3 fragmentPos = view.xyz;

	float occlusion = 0.0;

	ivec2 texel = ivec2(mod(floor(SCREEN_UV * push_constants.VIEWPORT_SIZE), 4.0));
    vec2 noiseVec = texelFetch(noiseTexture,texel,0).xy;

	vec3 normal = texture(normalTexture,SCREEN_UV).xyz;
	normal = normalize(normal * 2.0 - 1.0);

	vec3 randomVec = normalize(vec3(noiseVec,0.0));
	vec3 tangent = normalize(randomVec - normal * dot(randomVec,normal));	
	vec3 bitangent = cross(normal,tangent);
	mat3 TBN = mat3(tangent,bitangent,normal);

	for(int i = 0; i < SAMPLE_COUNT; i++){

		//orient kernal to surface normal
		vec3 sampleOffset =	TBN * samples[i];

		//position near our fragment
		vec3 samplePos = fragmentPos + sampleOffset * push_constants.radius;

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
			push_constants.radius / abs(fragmentPos.z - sampleView.z)
		);

		//is the real geometry closer to the camera than my imaginary sample? If yes sample is blocked occlusion = 1;
		occlusion += (sampleView.z > samplePos.z? 1.0 : 0.0) * rangeCheck;
        
	}

    occlusion /= float(SAMPLE_COUNT);

	float ao = 1.0 - occlusion;
	ao = pow(ao,2);

    imageStore(
        aoImage,
        pixel,
        vec4(ao, 0.0, 0.0, 1.0)
    );
}