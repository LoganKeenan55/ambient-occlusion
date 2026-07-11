shader_type spatial;

uniform sampler2D depthTexture:hint_depth_texture;

void vertex(){
}


void fragment() {
	float depth = texture(depthTexture, SCREEN_UV).r;

	depth = PROJECTION_MATRIX[3][2] / (depth + PROJECTION_MATRIX[2][2]);

	ALBEDO = vec3(depth*0.02f);
	//ALPHA = 0.5f;
}
