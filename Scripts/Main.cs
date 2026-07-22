using System;
using System.Drawing;
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
	   createRandomPoints(64);
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

	public void createRandomPoints(int count){
		Vector3[] points = new Vector3[count];

		//generate random directions
		for(int i = 0; i < count; i++){
			float x = (float)Math.Round(GD.Randf()*2-1,2);
			float y = (float)Math.Round(GD.Randf()*2-1,2);
			float z = (float)Math.Round(GD.Randf(),2);
			points[i] = new Vector3(x, y, z);
		}

		//randomize lengths
		for(int i = 0; i < count; i++){
			Vector3 normalized = points[i].Normalized();
			float scale = Mathf.Lerp(0.1f, 1.0f, (float)i/count*i/count);
			points[i] = normalized * scale;
			points[i] = new Vector3(
            (float)Math.Round(points[i].X, 2),
            (float)Math.Round(points[i].Y, 2),
            (float)Math.Round(points[i].Z, 2)
        );
		}

		foreach(Vector3 p in points){
			GD.Print("vec3(",p.X,",",p.Y,",",p.Z,"),");
		}
	}
	public void setssaoNoiseTexture(){
		for(int i = 0; i < 4; i++){
			for(int j = 0; j < 4; j++){
				Vector3 value = new Vector3(GD.Randf(),GD.Randf(),0).Normalized();

				ssaoNoiseImage.SetPixel(i, j, new Godot.Color(value.X,value.Y,0.5f));
			}
		}
				ssaoNoiseTexture = ImageTexture.CreateFromImage(ssaoNoiseImage);
	}
}