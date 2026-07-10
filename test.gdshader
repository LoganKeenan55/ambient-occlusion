shader_type spatial;
render_mode unshaded;

uniform vec3 lightPos;
uniform vec3 worldPos;
uniform vec3 	

vec3 lambertionDiffuse(vec3 normal){
	float ambient = 0.1f;
	vec3 lightVector = normalize(lightPos - worldPos);
	float diffuse = max(dot(normal,lightVector),0.0f);
	return vec3(ambient + diffuse);
}


void fragment() {
	ALBEDO = lambertionDiffuse(NORMAL);
}

void light() {
//
}

