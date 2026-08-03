using Godot;
using System;

public partial class Sample : AnimatedSprite2D
{
	private bool occluded = false;

	public override void _Ready(){
		
	}

	public override void _Process(double delta){
		
	}

	public void _on_area_2d_area_entered(Area2D area){
		Play("occluded");
		occluded = true;
	}
		public void _on_area_2d_area_exited(Area2D area){
		Play("unOccluded");
		occluded = false;
	}


	public bool getOccluded(){
		return occluded;
	}
}
