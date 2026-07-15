using System;
using System.Runtime.InteropServices;
using System.Runtime.Intrinsics.X86;
using Godot;

public partial class Main : Node3D
{
	private ShaderMaterial material;
	private MeshInstance3D shaderOverlay;
	private WorldEnvironment worldEnvironment;

	Image ssaoNoiseImage = Image.CreateEmpty(4, 4, false, Image.Format.Rgb8);
	ImageTexture ssaoNoiseTexture;
	[Export]
	private int mode;

    public override void _Ready(){
       worldEnvironment = GetNode<WorldEnvironment>("WorldEnvironment");
    }

    public override void _Process(double _delta){
		if(Input.IsActionJustPressed("esc")){
			GetTree().Quit(); 
		}

		if (Input.IsActionJustPressed("1")){
			worldEnvironment.Compositor.CompositorEffects[0].Set("renderMode",0);
		}
		if (Input.IsActionJustPressed("2")){
			worldEnvironment.Compositor.CompositorEffects[0].Set("renderMode",1);
		}
		if (Input.IsActionJustPressed("3")){
			worldEnvironment.Compositor.CompositorEffects[0].Set("renderMode",2);
		}
    }

	public void createRandomPoints(int count,float max, float min){
		for(int i = 0; i < count; i++){
			GD.Print("vec3(",Math.Round(GD.Randf()*max-min,2),",",Math.Round(GD.Randf()*max-min,2),",",Math.Round(GD.Randf()*max-min,2),"),");
		}
	}

	public void setssaoNoiseTexture(){
		for(int i = 0; i < 4; i++){
			for(int j = 0; j < 4; j++){
				Vector3 value = new Vector3(GD.Randf(),GD.Randf(),0).Normalized();

				ssaoNoiseImage.SetPixel(i, j, new Color(value.X,value.Y,0.5f));
			}
		}
				ssaoNoiseTexture = ImageTexture.CreateFromImage(ssaoNoiseImage);
	}
}