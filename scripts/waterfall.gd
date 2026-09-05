extends Node3D

const Layout = preload("res://scripts/valley_layout.gd")
var material: ShaderMaterial
var sound: AudioStreamPlayer3D
var foam: MultiMeshInstance3D
var elapsed := 0.0
var active := true

func _ready() -> void:
	position = Layout.FALL
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float flow_time = 0.0;
void fragment() {
    float column = floor(UV.x * 32.0);
    float seed = fract(sin(column * 127.1) * 43758.5453);
    float flow = fract(UV.y * 7.0 - flow_time * 1.2 + seed * 7.0);
    float streak = smoothstep(0.68,0.95,flow) * step(0.3,seed);
    vec3 water = mix(vec3(0.15,0.37,0.43),vec3(0.37,0.61,0.63),seed * 0.55);
    water = mix(water,vec3(0.71,0.86,0.83),streak * 0.55);
    ALBEDO = pow(water,vec3(2.2));
    ROUGHNESS = 0.65;
    EMISSION = ALBEDO * 0.02;
}
"""
	material = ShaderMaterial.new()
	material.shader = shader
	var curtain := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(9,Layout.FALL_TOP-Layout.FALL_BOTTOM)
	curtain.mesh = plane
	curtain.position = Vector3(0,-0.5,0.03)
	curtain.material_override = material
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curtain)
	# Small opaque splash pieces avoid a stack of expensive transparent particle layers.
	foam = MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.4,0.14,0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c5e5df")
	mat.roughness = 0.6
	box.material = mat
	multimesh.mesh = box
	multimesh.instance_count = 36
	foam.multimesh = multimesh
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)
	sound = AudioStreamPlayer3D.new()
	sound.stream = make_water_sound()
	sound.position = Vector3(0,-10,2)
	sound.max_distance = 85
	sound.unit_size = 12
	sound.volume_db = -21
	add_child(sound)
	sound.play()

static func make_water_sound() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = 44100
	var bytes := PackedByteArray()
	bytes.resize(44100*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 841
	var low := 0.0
	for i in 44100:
		var n := rng.randf_range(-1,1)
		low = lerpf(low,n,0.18)
		var envelope := minf(1,minf(i/180.0,(44099-i)/180.0))
		bytes.encode_s16(i*2,int((n*0.16+low*0.65)*envelope*22000))
	wav.data = bytes
	return wav

func set_active(value: bool) -> void:
	active = value
	if sound != null: sound.stream_paused = not value

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	material.set_shader_parameter("flow_time",elapsed)
	for i in 36:
		var phase := fmod(elapsed*0.55+i*0.173,1.0)
		var x := -4.5+float(i%12)*0.82+sin(i*3.0)*0.15
		var y := -17.8+sin(phase*PI)*0.9
		var z := 0.4+phase*4.0+(i/12)*0.4
		foam.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x,y,z)))
