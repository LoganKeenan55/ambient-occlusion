using System;
using System.Runtime.InteropServices;
using System.Runtime.Intrinsics.X86;
using Godot;

public partial class Main : Node3D
{
	private ShaderMaterial material;
	private MeshInstance3D shaderOverlay;
<<<<<<< HEAD
	private MeshInstance3D blurOverlay;
	private Camera3D ssaoCamera;

	private Camera3D blurCamera;
=======
>>>>>>> parent of ef9ec30 (nothing works everything is broken)

	Image ssaoNoiseImage = Image.CreateEmpty(4, 4, false, Image.Format.Rgb8);
	ImageTexture ssaoNoiseTexture;
	[Export]
	private int mode;


    public override void _Ready(){
<<<<<<< HEAD
		ssaoCamera = GetNode<Camera3D>("SSAOCamera");

		shaderOverlay = GetNode<MeshInstance3D>("SSAOCamera/SSAO");
=======
		shaderOverlay = GetNode<Camera3D>("Camera").GetNode<MeshInstance3D>("SSAO");
>>>>>>> parent of ef9ec30 (nothing works everything is broken)
		material = (ShaderMaterial)shaderOverlay.GetActiveMaterial(0);
		
		setssaoNoiseTexture();
		material.SetShaderParameter("noiseTexture",ssaoNoiseTexture);
<<<<<<< HEAD
		//blurOverlay = GetNode<MeshInstance3D>("SubViewportContainer/BlurViewport/BlurCamera/Blur");
		//ShaderMaterial blurMaterial = (ShaderMaterial)blurOverlay.GetActiveMaterial(0);
		
=======
>>>>>>> parent of ef9ec30 (nothing works everything is broken)

		material.SetShaderParameter("mode",mode);
		//createRandomPoints(200,2.0f,1.0f);


	}

    public override void _Process(double delta){
<<<<<<< HEAD

=======
>>>>>>> parent of ef9ec30 (nothing works everything is broken)
		if (Input.IsActionJustPressed("esc")){
			GetTree().Quit(); 
			
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