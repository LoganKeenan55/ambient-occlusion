shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform sampler2D depthTexture:hint_depth_texture;
uniform sampler2D screenTexture:hint_screen_texture;
uniform sampler2D noiseTexture : source_color, repeat_enable;

uniform int mode;

void vertex(){
}


void fragment() {
	
	//depth at current fragment
	float depth = texture(depthTexture, SCREEN_UV).r;

	//convert SCREEN_UV from 0,1 to clip space -1,-1
	vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, texture(depthTexture, SCREEN_UV).r, 1.0);

	//get view space from inverting proj matrix from clip space
	vec4 view = INV_PROJECTION_MATRIX * clip;

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

	const vec2 noiseScale = VIEWPORT_SIZE / 4.0;
	vec2 noiseVec = texture(noiseTexture, SCREEN_UV * noiseScale).xy * 2.0 - 1.0;
	float noiseAngle = atan(noiseVec.y,noiseVec.x);

	mat2 rotationMatrix = mat2(vec2(cos(noiseAngle),sin(noiseAngle)),vec2(-sin(noiseAngle),cos(noiseAngle)));
	
	for(int i = 0; i < SAMPLE_COUNT; i++){

		vec3 sample = normalize(samples[i]) * radius;

		sample.xy = rotationMatrix * sample.xy;

		//position near our fragment
		vec3 samplePos = fragmentPos + sample ;

		//go back to clipspace
		vec4 offset = PROJECTION_MATRIX * vec4(samplePos,1.0f);
		offset.xyz /= offset.w;
		offset.xy = offset.xy * 0.5 + 0.5; //tranform back to 0.0 - 1.0
		
		//get depth of sample
		float sampleDepth = texture(depthTexture,offset.xy).r;

		//go back again to clip space
		vec4 sampleClip = vec4(offset.xy * 2.0 - 1.0, sampleDepth, 1.0);

		//view space
		vec4 sampleView = INV_PROJECTION_MATRIX * sampleClip;

		//perspective divide
		sampleView /= sampleView.w;
		//NOW we have sampleView .xyz which is geometry at that sampled screen location

		//distance from fragment we are shading and geometry
		float rangeCheck = smoothstep(0.0,1.0,radius / abs(fragmentPos.z - sampleView.z));

		//is the real geometry closer to the camera than my imaginary sample? If yes sample is blocked occlusion = 1;
		occlusion += (sampleView.z > samplePos.z? 1.0 : 0.0) * rangeCheck;
		

	}

	occlusion /= float(SAMPLE_COUNT);

	float ao = 1.0 - occlusion;

	vec4 screen = texture(screenTexture, SCREEN_UV);

	if(mode == 0){
		ALBEDO =  texture(screenTexture,SCREEN_UV).rgb;
		ALPHA = screen.a;
	}
	else if (mode == 1){
		ALBEDO =  vec3(ao);
		ALPHA = screen.a;
	}
	else if (mode == 2){
		ALBEDO =  texture(screenTexture,SCREEN_UV).rgb * ao;
		ALPHA = screen.a;
	}

}