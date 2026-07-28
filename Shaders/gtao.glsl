//GTAO implementation based on Activision's Practical Real-Time Strategies for Accurate Indirect Occlusion
//reference: Intel's XeGTAO - https://github.com/GameTechDev/XeGTAO
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

const int slices = 8; //directions swept per pixel
const int stepsPerSlice = 8; //horizon steps per side, per slice
const float falloffRange = 0.4; //fraction of radius samples fade out over
const float power = 1.5; //artistic control! oh no!
const float PI = 3.14159265358979;
const float HALF_PI = 1.57079632679;

vec3 getViewPos(vec2 uv) {
	float depth = texture(depthTexture, uv).r;
	vec4 clip = vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec4 view = camera.INV_PROJECTION_MATRIX * clip;
	view /= view.w;
	return view.xyz;
}

float integrateSlice(float n, float cosNorm, float h0, float h1) {
	float iarc0 = (cosNorm + 2.0 * h0 * sin(n) - cos(2.0 * h0 - n)) / 4.0;
	float iarc1 = (cosNorm + 2.0 * h1 * sin(n) - cos(2.0 * h1 - n)) / 4.0;
	return iarc0 + iarc1;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

	if (pixel.x >= int(push_constants.VIEWPORT_SIZE.x) || pixel.y >= int(push_constants.VIEWPORT_SIZE.y)){
		return;
	}

	vec2 SCREEN_UV = (vec2(pixel) + vec2(0.5)) / push_constants.VIEWPORT_SIZE;

	vec3 C = getViewPos(SCREEN_UV);

	vec3 normal = texture(normalTexture, SCREEN_UV).xyz;
	normal = normalize(normal * 2.0 - 1.0); //view space normal

	vec3 viewVec = normalize(-C);

	ivec2 texel = ivec2(mod(floor(SCREEN_UV * push_constants.VIEWPORT_SIZE), 4.0));
	vec2 noiseVec = texelFetch(noiseTexture, texel, 0).xy;
	float noiseSlice = noiseVec.x;
	float noiseStep = noiseVec.y;

	float projScale = abs(camera.PROJECTION_MATRIX[1][1]) * push_constants.VIEWPORT_SIZE.y * 0.5;
	float screenspaceRadius = projScale * push_constants.radius / max(-C.z, 0.001);

	float falloffFrom = push_constants.radius * (1.0 - falloffRange);
	float falloffRangeInv = falloffRange * push_constants.radius;
	float falloffMul = -1.0 / falloffRangeInv;
	float falloffAdd = falloffFrom / falloffRangeInv + 1.0;

	float visibility = 0.0;

	for (int slice = 0; slice < slices; slice++) {
		float sliceK = (float(slice) + noiseSlice) / float(slices);
		float phi = sliceK * PI;
		float cosPhi = cos(phi);
		float sinPhi = sin(phi);
		vec2 omega = vec2(cosPhi, -sinPhi) * screenspaceRadius;

		vec3 directionVec = vec3(cosPhi, sinPhi, 0.0);
		vec3 orthoDirectionVec = directionVec - dot(directionVec, viewVec) * viewVec;
		vec3 axisVec = normalize(cross(orthoDirectionVec, viewVec));
		vec3 projectedNormalVec = normal - axisVec * dot(normal, axisVec);
		float projectedNormalVecLength = length(projectedNormalVec);

		float signNorm = sign(dot(orthoDirectionVec, projectedNormalVec));
		float cosNorm = clamp(dot(projectedNormalVec, viewVec) / max(projectedNormalVecLength, 0.0001), -1.0, 1.0);
		float n = signNorm * acos(cosNorm);

		float lowHorizonCos0 = cos(n + HALF_PI);
		float lowHorizonCos1 = cos(n - HALF_PI);
		float horizonCos0 = lowHorizonCos0;
		float horizonCos1 = lowHorizonCos1;

		for (int step = 0; step < stepsPerSlice; step++) {
			float stepNoise = fract(noiseStep + float(step) * 0.6180339887);
			float s = (float(step) + stepNoise) / float(stepsPerSlice);

			vec2 uvOffset = (s * omega) / push_constants.VIEWPORT_SIZE;

			vec2 sampleUV0 = SCREEN_UV + uvOffset;
			vec2 sampleUV1 = SCREEN_UV - uvOffset;

			vec3 samplePos0 = getViewPos(sampleUV0);
			vec3 samplePos1 = getViewPos(sampleUV1);

			vec3 delta0 = samplePos0 - C;
			vec3 delta1 = samplePos1 - C;
			float dist0 = length(delta0);
			float dist1 = length(delta1);

			vec3 horizonVec0 = delta0 / max(dist0, 0.0001);
			vec3 horizonVec1 = delta1 / max(dist1, 0.0001);

			float weight0 = clamp(dist0 * falloffMul + falloffAdd, 0.0, 1.0);
			float weight1 = clamp(dist1 * falloffMul + falloffAdd, 0.0, 1.0);

			float shc0 = mix(lowHorizonCos0, dot(horizonVec0, viewVec), weight0);
			float shc1 = mix(lowHorizonCos1, dot(horizonVec1, viewVec), weight1);

			horizonCos0 = max(horizonCos0, shc0);
			horizonCos1 = max(horizonCos1, shc1);
		}

		float h0 = -acos(horizonCos1);
		float h1 = acos(horizonCos0);

		visibility += projectedNormalVecLength * integrateSlice(n, cosNorm, h0, h1);
	}

	visibility /= float(slices);
	float ao = pow(clamp(visibility, 0.0, 1.0), power);
	ao = max(ao, 0.03); //never fully black

	imageStore(
		aoImage,
		pixel,
		vec4(ao, 0.0, 0.0, 1.0)
	);
}
