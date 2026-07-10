using Godot;
using System;

public partial class Main : Node3D
{
	private MeshInstance3D light;
	private MeshInstance3D wall;
	private ShaderMaterial material;

	public override void _Ready(){
		light = GetNode<MeshInstance3D>("Light");
		wall = GetNode<MeshInstance3D>("Wall");
		material = (ShaderMaterial)wall.GetActiveMaterial(0);
	}

	public override void _Process(double delta){
		material.SetShaderParameter("lightPos",light.GlobalPosition);
		material.SetShaderParameter("worldPos",wall.GlobalPosition);
	}
}
