shader_type spatial;
render_mode cull_disabled,world_vertex_coords;
uniform sampler2D gradient:repeat_disable;
uniform sampler2D color_gradient: source_color,repeat_disable;

uniform sampler2D burn_noise: filter_linear;

uniform sampler2D t1_normal: filter_linear;
uniform sampler2D t2_normal: filter_linear;
uniform sampler2D t1_orm: filter_linear;
uniform sampler2D t2_orm: filter_linear;
uniform vec3 color1: source_color;
uniform vec3 color2: source_color;

uniform vec3 center_pos;
varying mat4 modelview_matrix;
varying mat4 model_matrix;
varying float steepness;
varying float dist;

varying vec3 uv1_power_normal;
uniform float uv1_blend_sharpness : hint_range(0.0, 150.0, 0.001);
varying vec3 uv1_triplanar_pos;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform bool adjust_normal = false;
float blendColorBurn(float base, float blend) {
	return (blend==0.0)?blend:max((1.0-((1.0-base)/blend)),0.0);
}

vec3 blendColorBurnv3(vec3 base, vec3 blend) {
	return vec3(blendColorBurn(base.r,blend.r),blendColorBurn(base.g,blend.g),blendColorBurn(base.b,blend.b));
}
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}
void vertex() {
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	if (adjust_normal == true){
		TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
		TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
		TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
		TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(TANGENT);

		BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
		BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
		BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
		BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(BINORMAL);
	}
	// UV1 Triplanar: Enabled (with World Triplanar)
	uv1_power_normal = pow(abs(normal), vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * uv1_scale + uv1_offset;
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
	modelview_matrix =MODELVIEW_MATRIX;
	model_matrix = MODEL_MATRIX;
	steepness = dot(normalize(VERTEX-center_pos),NORMAL);
	dist = length(VERTEX);
}

void fragment() {

	vec3 worldNormal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL).xyz;
	vec3 worldVtex = normalize(mat3(model_matrix) * VERTEX).xyz;
	float steep = dot(worldNormal,worldVtex);
	float mixval = texture(gradient,vec2(steepness,normalize(dist))).r;
	ALBEDO = texture(color_gradient,vec2(mixval*0.9,0.)).rgb;

	//NORMAL_MAP = mix(triplanar_texture(t1_normal,uv1_power_normal, uv1_triplanar_pos),triplanar_texture(t2_normal,uv1_power_normal, uv1_triplanar_pos),mixval).rgb;
	//ROUGHNESS = mix(triplanar_texture(t1_orm,uv1_power_normal, uv1_triplanar_pos),triplanar_texture(t2_orm,uv1_power_normal, uv1_triplanar_pos),mixval).g;
	//METALLIC = mix(triplanar_texture(t1_orm,uv1_power_normal, uv1_triplanar_pos),triplanar_texture(t2_orm,uv1_power_normal, uv1_triplanar_pos),mixval).b;
	//if (color.x < 0.){
		//ALBEDO = vec3(1.,1.,0.);
	//}
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
