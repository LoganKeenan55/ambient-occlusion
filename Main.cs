using System;
using Godot;

public partial class Main : Node3D
{

    public override void _Ready(){
		createRandomPoints(20,2.0f,1.0f);
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