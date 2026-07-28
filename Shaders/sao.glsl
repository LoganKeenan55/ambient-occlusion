//Scalable Ambient Obscurence based on NVidia paper
//~.70ms cost w/ 11 samples on rtx 2070
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

const int samples = 11; //11
const int spiralTurns = 7; //7
const float EPSILON = 0.01;
const float intensity = 0.3;
const float power = 1.5; //artistic control! oh no!
const float TAU = 6.28318530718;

vec3 getViewPos(vec2 uv) {
	float depth = texture(depthTexture, uv).r;
	vec4 clip = vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec4 view = camera.INV_PROJECTION_MATRIX * clip;
	view /= view.w;
	return view.xyz;
}

float sampleAO(vec3 C, vec2 screenSpaceC, vec3 normalC, float screenSpaceDiskRadius, int sampleIndex, float randAngle, float radius, float bias){
    //do spiral pattern
    float alpha = (float(sampleIndex) + 0.5) * (1.0 / float(samples));
    float angle = alpha * (float(spiralTurns) * TAU) + randAngle;
	vec2 unitOffset = vec2(cos(angle), sin(angle));
	float screenSpaceRadius = alpha * screenSpaceDiskRadius;
    
    //find UV of sample pixel
    vec2 sampleUV = screenSpaceC + (screenSpaceRadius * unitOffset) / push_constants.VIEWPORT_SIZE;

    //actual 3D point 
    vec3 Q = getViewPos(sampleUV);

    //from center point to sample point
    vec3 direction =  Q - C; 

    float dirLength = dot(direction,direction);
    float heightAlongNormal = dot(direction, normalC);

    float distanceFallOff = max((radius * radius) - dirLength, 0.0);
    return distanceFallOff * distanceFallOff * distanceFallOff * max((heightAlongNormal - bias) / (EPSILON + dirLength), 0.0);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

	if (pixel.x >= int(push_constants.VIEWPORT_SIZE.x) || pixel.y >= int(push_constants.VIEWPORT_SIZE.y)){
		return;
    }

	vec2 SCREEN_UV = (vec2(pixel) + vec2(0.5)) / push_constants.VIEWPORT_SIZE;

	vec3 C = getViewPos(SCREEN_UV);

	vec3 normal = texture(normalTexture, SCREEN_UV).xyz;
	normal = normalize(normal * 2.0 - 1.0); // view space normal

	ivec2 texel = ivec2(mod(floor(SCREEN_UV * push_constants.VIEWPORT_SIZE), 4.0));
	vec2 noiseVec = texelFetch(noiseTexture, texel, 0).xy;
	float randomAngle = atan(noiseVec.y, noiseVec.x);

	float projScale = abs(camera.PROJECTION_MATRIX[1][1]) * push_constants.VIEWPORT_SIZE.y * 0.5;
	float screenSpaceDiskRadius = projScale * push_constants.radius / max(-C.z, 0.001);

	float bias = 0.05 * push_constants.radius; //scale bias with radius
	float sum = 0.0;
	for (int i = 0; i < samples; i++) {
		sum += sampleAO(C, SCREEN_UV, normal, screenSpaceDiskRadius, i, randomAngle,  push_constants.radius, bias);
	}

	float intensityDivR6 = intensity / pow(push_constants.radius, 6.0);
	float A = max(0.0, 1.0 - sum * intensityDivR6 * (5.0 / float(samples)));
	float ao = pow(A, power);

	imageStore(
		aoImage,
		pixel,
		vec4(ao, 0.0, 0.0, 1.0)
	);
}
