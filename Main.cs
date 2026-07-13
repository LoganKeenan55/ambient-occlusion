using System;
using Godot;

public partial class Main : Node3D
{
	private ShaderMaterial material;
	private MeshInstance3D shaderOverlay;
	[Export]
	private int mode;


    public override void _Ready(){
		shaderOverlay = GetNode<Camera3D>("Camera").GetNode<MeshInstance3D>("SSAO");
		material = (ShaderMaterial)shaderOverlay.GetActiveMaterial(0);
		material.SetShaderParameter("mode",mode);
		//createRandomPoints(200,2.0f,1.0f);


	}

    public override void _Process(double delta){
		if (Input.IsActionJustPressed("esc")){
			GetTree().Quit(); 
			
		}
    }

	public void createRandomPoints(int count,float max, float min){
		for(int i = 0; i < count; i++){
			GD.Print("vec3(",Math.Round(GD.Randf()*max-min,2),",",Math.Round(GD.Randf()*max-min,2),",",Math.Round(GD.Randf()*max-min,2),"),");
		}
	}
}