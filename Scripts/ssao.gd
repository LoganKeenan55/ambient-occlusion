@tool
extends CompositorEffect
class_name SSAOEffect

@export_enum("Flat", "AO Only", "Composited") var renderMode: int = 2

var rd: RenderingDevice

var shader: RID
var pipeline: RID

var blur_shader: RID
var blur_pipeline: RID

var ao_texture: RID
var ao_texture_size := Vector2i.ZERO

var depth_sampler: RID
var noise_sampler: RID

var camera_uniform: RID
var noise_image: Image
var noise_texture: ImageTexture
var rd_noise_texture: RID

var ao_sampler: RID

@export_range(0.1,10,0.1) var radius: float;

func _init():
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT

	rd = RenderingServer.get_rendering_device()

	var shader_file = preload("res://Shaders/ssao.glsl")
	var shader_spirv = shader_file.get_spirv()

	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	var blur_file = load("res://Shaders/bilateralBlur.glsl")

	var blur_spirv = blur_file.get_spirv()

	blur_shader = rd.shader_create_from_spirv(blur_spirv)


	blur_pipeline = rd.compute_pipeline_create(blur_shader)
	print("blur shader valid =", blur_shader.is_valid())
	print("blur pipeline valid =", blur_pipeline.is_valid())

	depth_sampler = rd.sampler_create(RDSamplerState.new())
	noise_sampler = rd.sampler_create(RDSamplerState.new())
	ao_sampler = rd.sampler_create(RDSamplerState.new())

	createNoiseTexture()
	uploadNoiseTexture()


func _notification(what):
	if what != NOTIFICATION_PREDELETE:
		return

	if shader.is_valid():
		rd.free_rid(shader)

	if pipeline.is_valid():
		rd.free_rid(pipeline)

	if depth_sampler.is_valid():
		rd.free_rid(depth_sampler)

	if noise_sampler.is_valid():
		rd.free_rid(noise_sampler)

	if rd_noise_texture.is_valid():
		rd.free_rid(rd_noise_texture)

	if camera_uniform.is_valid():
		rd.free_rid(camera_uniform)
	if ao_texture.is_valid():
		rd.free_rid(ao_texture)

	if blur_shader.is_valid():
		rd.free_rid(blur_shader)

	if blur_pipeline.is_valid():
		rd.free_rid(blur_pipeline)
	if ao_sampler.is_valid():
		rd.free_rid(ao_sampler)

func _render_callback(_callback_type:int, render_data:RenderData):
	var scene_buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD

	if scene_buffers == null:
		return

	var size := scene_buffers.get_internal_size()

	if !ao_texture.is_valid() or ao_texture_size != size:
		_create_ao_texture(size)

	if size.x == 0 or size.y == 0:
		return

	var scene_data = render_data.get_render_scene_data()

	var projection = scene_data.get_cam_projection()
	var inv_projection = projection.inverse()
	var camera_bytes := PackedByteArray()

	camera_bytes.append_array(
		PackedVector4Array([
			projection.x,
			projection.y,
			projection.z,
			projection.w
		]).to_byte_array()
	)

	camera_bytes.append_array(
		PackedVector4Array([
			inv_projection.x,
			inv_projection.y,
			inv_projection.z,
			inv_projection.w
		]).to_byte_array()
	)

	if camera_uniform.is_valid():
		rd.free_rid(camera_uniform)

	camera_uniform = rd.uniform_buffer_create(
		camera_bytes.size(),
		camera_bytes
	)

	var push_constants := PackedFloat32Array([
		size.x,
		size.y,
		radius,
		0.0
	]).to_byte_array()

	var blur_push_constants := PackedFloat32Array([
		size.x,
		size.y,
		float(renderMode),
		0.0
	]).to_byte_array()


	for view in scene_buffers.get_view_count():
		var normal_uniform := RDUniform.new()
		normal_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		normal_uniform.binding = 4
		normal_uniform.add_id(depth_sampler)
		normal_uniform.add_id(scene_buffers.get_texture("forward_clustered", "normal_roughness"))

		var ao_uniform := RDUniform.new()
		ao_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		ao_uniform.binding = 0
		ao_uniform.add_id(ao_texture)

		var depth_uniform := RDUniform.new()
		depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth_uniform.binding = 1
		depth_uniform.add_id(depth_sampler)
		depth_uniform.add_id(scene_buffers.get_depth_layer(view))

		var noise_uniform := RDUniform.new()
		noise_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		noise_uniform.binding = 2
		noise_uniform.add_id(noise_sampler)
		noise_uniform.add_id(rd_noise_texture)

		var camera_rd_uniform := RDUniform.new()
		camera_rd_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
		camera_rd_uniform.binding = 3
		camera_rd_uniform.add_id(camera_uniform)
		var bindings: Array[RDUniform] = [
			ao_uniform,
			depth_uniform,
			noise_uniform,
			camera_rd_uniform,
			normal_uniform
		]
		var uniform_set := rd.uniform_set_create(
			bindings,
			shader,
			0
		)

		var groups := Vector3i(
			ceili(size.x / 8.0),
			ceili(size.y / 8.0),
			1
		)

		var compute_list := rd.compute_list_begin()

		rd.compute_list_bind_compute_pipeline(
			compute_list,
			pipeline
		)

		rd.compute_list_bind_uniform_set(
			compute_list,
			uniform_set,
			0
		)

		rd.compute_list_set_push_constant(
			compute_list,
			push_constants,
			push_constants.size()
		)

		rd.compute_list_dispatch(
			compute_list,
			groups.x,
			groups.y,
			groups.z
		)

		rd.compute_list_end()

		rd.free_rid(uniform_set)

		var blur_color := RDUniform.new()
		blur_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		blur_color.binding = 0
		blur_color.add_id(scene_buffers.get_color_layer(view))

		var blur_ao := RDUniform.new()
		blur_ao.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		blur_ao.binding = 1
		blur_ao.add_id(ao_sampler)
		blur_ao.add_id(ao_texture)

		var blur_depth := RDUniform.new()
		blur_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		blur_depth.binding = 2
		blur_depth.add_id(depth_sampler)
		blur_depth.add_id(scene_buffers.get_depth_layer(view))

		var blur_bindings: Array[RDUniform] = [
		blur_color,
		blur_ao,
		blur_depth
		]

		var blur_uniform_set := rd.uniform_set_create(
			blur_bindings,
			blur_shader,
			0
		)
		var blur_compute := rd.compute_list_begin()

		rd.compute_list_bind_compute_pipeline(
			blur_compute,
			blur_pipeline
		)

		rd.compute_list_bind_uniform_set(
			blur_compute,
			blur_uniform_set,
			0
		)

		rd.compute_list_set_push_constant(
			blur_compute,
			blur_push_constants,
			blur_push_constants.size()
		)

		rd.compute_list_dispatch(
			blur_compute,
			groups.x,
			groups.y,
			groups.z
		)

		rd.compute_list_end()

		rd.free_rid(blur_uniform_set)



func createNoiseTexture():
	noise_image = Image.create_empty(
		4,
		4,
		false,
		Image.FORMAT_RGBA8
	)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(4):
		for j in range(4):

			var value := Vector3(rng.randf_range(-1.0, 1.0),rng.randf_range(-1.0, 1.0),0.0).normalized()

			noise_image.set_pixel(j,i,Color(value.x * 0.5 + 0.5, value.y * 0.5 + 0.5, 0.5,1.0))

	noise_texture = ImageTexture.create_from_image(noise_image)


func uploadNoiseTexture():
	if rd_noise_texture.is_valid():
		rd.free_rid(rd_noise_texture)

	if noise_texture == null:
		return

	var img := noise_texture.get_image()

	if img.is_compressed():
		img.decompress()

	img.convert(Image.FORMAT_RGBA8)

	var format := RDTextureFormat.new()
	format.width = img.get_width()
	format.height = img.get_height()
	format.depth = 1
	format.array_layers = 1
	format.mipmaps = 1
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM

	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)

	var view := RDTextureView.new()

	rd_noise_texture = rd.texture_create(
		format,
		view,
		[img.get_data()]
	)

func _create_ao_texture(size: Vector2i):
	if ao_texture.is_valid():
		rd.free_rid(ao_texture)

	var format := RDTextureFormat.new()

	format.width = size.x
	format.height = size.y
	format.depth = 1
	format.array_layers = 1
	format.mipmaps = 1
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D

	format.format = RenderingDevice.DATA_FORMAT_R16_SFLOAT

	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)

	var view := RDTextureView.new()

	ao_texture = rd.texture_create(
		format,
		view,
		[]
	)

	ao_texture_size = size
