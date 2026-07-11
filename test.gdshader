shader_type spatial;

uniform sampler2D depthTexture:hint_depth_texture;

void vertex(){
}


void fragment() {
	
	vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, texture(depthTexture, SCREEN_UV).r, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * clip;
	view /= view.w;
	
	vec3 position = view.xyz;
	
	float depth = texture(depthTexture, SCREEN_UV).r;

	depth = PROJECTION_MATRIX[3][2] / (depth + PROJECTION_MATRIX[2][2]);

	ALBEDO = abs(position) *0.05;
	//ALPHA = 0.0f;
}
