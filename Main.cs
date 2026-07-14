using System;
using System.Runtime.InteropServices;
using System.Runtime.Intrinsics.X86;
using Godot;

public partial class Main : Node3D
{
	private ShaderMaterial material;
	private MeshInstance3D shaderOverlay;
	private MeshInstance3D blurOverlay;
	private Camera3D ssaoCamera;
	private SubViewport ssaoViewport;
	private SubViewport blurViewport;
	private Camera3D blurCamera;

	Image ssaoNoiseImage = Image.CreateEmpty(4, 4, false, Image.Format.Rgb8);
	ImageTexture ssaoNoiseTexture;
	[Export]
	private int mode;


    public override void _Ready(){
		blurCamera = GetNode<Camera3D>("SubViewportContainer/BlurViewport/BlurCamera");
		ssaoCamera = GetNode<Camera3D>("SubViewportContainer/SSAOViewport/SSAOCamera");
		ssaoViewport = GetNode<SubViewport>("SubViewportContainer/SSAOViewport");

		shaderOverlay = GetNode<MeshInstance3D>("SubViewportContainer/SSAOViewport/SSAOCamera/SSAO");
		material = (ShaderMaterial)shaderOverlay.GetActiveMaterial(0);
		
		setssaoNoiseTexture();
		material.SetShaderParameter("noiseTexture",ssaoNoiseTexture);
		blurViewport = GetNode<SubViewport>("SubViewportContainer/BlurViewport");
		blurOverlay = GetNode<MeshInstance3D>("SubViewportContainer/BlurViewport/BlurCamera/Blur");
		ShaderMaterial blurMaterial = (ShaderMaterial)blurOverlay.GetActiveMaterial(0);
		blurMaterial.SetShaderParameter(
			"aoTexture",
			ssaoViewport.GetTexture()
		);

		material.SetShaderParameter("mode",mode);
		//createRandomPoints(200,2.0f,1.0f);


	}

    public override void _Process(double delta){


		blurCamera.GlobalTransform = ssaoCamera.GlobalTransform;
		blurCamera.Fov = ssaoCamera.Fov;
		blurCamera.Near = ssaoCamera.Near;
		blurCamera.Far = ssaoCamera.Far;

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