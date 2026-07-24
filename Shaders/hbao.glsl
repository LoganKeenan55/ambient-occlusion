//HBAO implementation based on Scanberg's implementation of Nvidia directX implementation

#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform PushConstants {
	vec2 VIEWPORT_SIZE;
	float radius;
	float padding;
} push_constants;

const float AO_INTENSITY = 2.0;
const float AO_TAN_BIAS = 0.57735026919; //tan(30 deg)
const float AO_MAX_RADIUS_PIXELS = 50.0;
const int AO_NUM_DIRECTIONS = 24;
const int AO_NUM_STEPS = 16;

layout(std140, set = 0, binding = 3) uniform CameraData {
	mat4 PROJECTION_MATRIX;
	mat4 INV_PROJECTION_MATRIX;
} camera;

layout(r16f, set = 0, binding = 0) uniform image2D aoImage;

layout(set = 0, binding = 1) uniform sampler2D depthTexture;

layout(set = 0, binding = 2) uniform sampler2D noiseTexture;

//unused for hbao
layout(set = 0, binding = 4) uniform sampler2D normalTexture;

const float PI = 3.14159265;

vec2 AORes;
vec2 InvAORes;
float R;
float R2;
float NegInvR2;
vec2 FocalLen;


vec3 GetViewPos(vec2 uv)
{
	float depth = texture(depthTexture, uv).r;
	vec4 clip = vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec4 view = camera.INV_PROJECTION_MATRIX * clip;
	view /= view.w;
	return view.xyz;
}

float TanToSin(float x)
{
	return x * inversesqrt(x * x + 1.0);
}

float InvLength(vec2 v)
{
	return inversesqrt(dot(v, v));
}

float BiasedTangent(vec3 v)
{
	return v.z * InvLength(v.xy) + AO_TAN_BIAS;
}

float Tangent(vec3 P, vec3 S)
{
	return -(P.z - S.z) * InvLength(S.xy - P.xy);
}

float Length2(vec3 v)
{
	return dot(v, v);
}

vec3 MinDiff(vec3 P, vec3 Pr, vec3 Pl)
{
	vec3 V1 = Pr - P;
	vec3 V2 = P - Pl;
	return (Length2(V1) < Length2(V2)) ? V1 : V2;
}

vec2 SnapUVOffset(vec2 uv)
{
	return round(uv * AORes) * InvAORes;
}

float Falloff(float d2)
{
	return d2 * NegInvR2 + 1.0;
}

float HorizonOcclusion(vec2 originUV, vec2 deltaUV, vec3 P, vec3 dPdu, vec3 dPdv, float randstep, float numSamples)
{
	float ao = 0.0;

	//offset the first sample with noise
	vec2 uv = originUV + SnapUVOffset(randstep * deltaUV);
	deltaUV = SnapUVOffset(deltaUV);

	vec3 T = deltaUV.x * dPdu + deltaUV.y * dPdv;

	float tanH = BiasedTangent(T);
	float sinH = TanToSin(tanH);

	for (float s = 1.0; s <= numSamples; s += 1.0)
	{
		uv += deltaUV;
		vec3 S = GetViewPos(uv);
		float tanS = Tangent(P, S);
		float d2 = Length2(S - P);

		if (d2 < R2 && tanS > tanH)
		{
			float sinS = TanToSin(tanS);
			ao += Falloff(d2) * (sinS - sinH);

			tanH = tanS;
			sinH = sinS;
		}
	}

	return ao;
}

vec2 RotateDirections(vec2 dir, vec2 cosSin)
{
	return vec2(dir.x * cosSin.x - dir.y * cosSin.y,
	            dir.x * cosSin.y + dir.y * cosSin.x);
}

void ComputeSteps(inout vec2 stepSizeUv, inout float numSteps, float rayRadiusPix, float rand)
{
	numSteps = min(float(AO_NUM_STEPS), rayRadiusPix);

	float stepSizePix = rayRadiusPix / (numSteps + 1.0);

	float maxNumSteps = AO_MAX_RADIUS_PIXELS / stepSizePix;
	if (maxNumSteps < numSteps)
	{
		numSteps = floor(maxNumSteps + rand);
		numSteps = max(numSteps, 1.0);
		stepSizePix = AO_MAX_RADIUS_PIXELS / numSteps;
	}

	stepSizeUv = stepSizePix * InvAORes;
}

void main(){
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

	if (pixel.x >= int(push_constants.VIEWPORT_SIZE.x) || pixel.y >= int(push_constants.VIEWPORT_SIZE.y))
		return;

	AORes = push_constants.VIEWPORT_SIZE;
	InvAORes = 1.0 / AORes;

	R = max(push_constants.radius, 0.0001);
	R2 = R * R;
	NegInvR2 = -1.0 / R2;

	FocalLen = vec2(camera.PROJECTION_MATRIX[0][0], camera.PROJECTION_MATRIX[1][1]);

	vec2 SCREEN_UV = (vec2(pixel) + vec2(0.5)) / AORes;

	vec3 P = GetViewPos(SCREEN_UV);

	vec3 Pr = GetViewPos(SCREEN_UV + vec2(InvAORes.x, 0.0));
	vec3 Pl = GetViewPos(SCREEN_UV - vec2(InvAORes.x, 0.0));
	vec3 Pt = GetViewPos(SCREEN_UV + vec2(0.0, InvAORes.y));
	vec3 Pb = GetViewPos(SCREEN_UV - vec2(0.0, InvAORes.y));

	vec3 dPdu = MinDiff(P, Pr, Pl);
	vec3 dPdv = MinDiff(P, Pt, Pb) * (AORes.y * InvAORes.x);

	ivec2 texel = ivec2(mod(floor(SCREEN_UV * AORes), 4.0));
	vec3 randTex = texelFetch(noiseTexture, texel, 0).xyz;


	//projected size of the AO hemisphere
	vec2 rayRadiusUV = 0.5 * R * FocalLen / max(-P.z, 0.0001);
	float rayRadiusPix = rayRadiusUV.x * AORes.x;

	float ao = 1.0;

	//skip shading if the hemisphere doesn't cover pixel
	if (rayRadiusPix > 1.0)
	{
		ao = 0.0;
		float numSteps;
		vec2 stepSizeUV;

		ComputeSteps(stepSizeUV, numSteps, rayRadiusPix, randTex.z);

		float alpha = 2.0 * PI / float(AO_NUM_DIRECTIONS);

		for (int d = 0; d < AO_NUM_DIRECTIONS; d++)
		{
			float theta = alpha * float(d);

			vec2 dir = RotateDirections(vec2(cos(theta), sin(theta)), randTex.xy);
			vec2 deltaUV = dir * stepSizeUV;

			ao += HorizonOcclusion(SCREEN_UV, deltaUV, P, dPdu, dPdv, randTex.z, numSteps);
		}

		ao = 1.0 - (ao / float(AO_NUM_DIRECTIONS)) * AO_INTENSITY;
	}

	ao = clamp(ao, 0.0, 1.0);

	imageStore(
		aoImage,
		pixel,
		vec4(ao, 0.0, 0.0, 1.0)
	);
}
