shader_type spatial;
render_mode cull_back;
uniform sampler2D gradient: filter_nearest,repeat_disable;
uniform vec3 center_pos;
varying mat4 modelview_matrix;
varying mat4 model_matrix;
varying float steepness;
varying float dist;
void vertex() {
	modelview_matrix =MODELVIEW_MATRIX;
	model_matrix = MODEL_MATRIX;
	steepness = dot(normalize(VERTEX),NORMAL);
	dist = length(VERTEX);
}

void fragment() {

	vec3 worldNormal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL).xyz;
	vec3 worldVtex = normalize(mat3(model_matrix) * VERTEX).xyz;
	float steep = dot(worldNormal,worldVtex);
	ALBEDO = texture(gradient,vec2(steepness,normalize(dist))).rgb;
	//if (color.x < 0.){
		//ALBEDO = vec3(1.,1.,0.);
	//}
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
