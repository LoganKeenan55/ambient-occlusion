using Godot;
using System;

public partial class Ssao2d : Node2D
{
	private Node2D samples;
	private Sprite2D wall;
	private Sprite2D blackSqaure;
	private Label label;


	private int occlusionValue = 0;
	private int sampleCount = 1;
	private float zoomSensitivity = 4.5f;


	public override void _Ready(){
		samples = GetNode<Node2D>("Samples");
		wall = GetNode<Sprite2D>("Wall");
		blackSqaure = GetNode<Sprite2D>("BlackSqaure");
		label = GetNode<Label>("Label");

		Input.MouseMode = Input.MouseModeEnum.Hidden;

		sampleCount = samples.GetChildCount();

	}

	public override void _Process(double delta){

		if (Input.IsActionJustPressed("esc")){
			GetTree().Quit(); 
		}

		if (Input.IsActionJustPressed("space")){
			label.Visible = true;
		}

		wall.GlobalPosition = GetGlobalMousePosition();

		occlusionValue = getOcclusionValue();

		label.Text = "Occlusion Value: " + Math.Round(occlusionValue / (float)sampleCount, 2);
		

		Color blackSquareColor = blackSqaure.Modulate;
		blackSquareColor.A = occlusionValue / (float)sampleCount + .1f;

		blackSqaure.Modulate = blackSquareColor;

		if (Input.IsActionJustPressed("scrollUp")){
			wall.Scale -= new Vector2(zoomSensitivity,zoomSensitivity);
		}
		if (Input.IsActionJustPressed("scrollDown")){
			wall.Scale += new Vector2(zoomSensitivity,zoomSensitivity);
		}

	}

	public int getOcclusionValue(){
		int count = 0;
		for(int i = 0; i < samples.GetChildCount(); i++){
			count += (samples.GetChild(i) as Sample).getOccluded() ? 1 : 0;
		}
		return count;
	}


}
