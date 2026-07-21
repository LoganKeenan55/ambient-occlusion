using Godot;
using System;

public partial class LegacyMain : Node3D
{
	private ShaderMaterial material;
	private MeshInstance3D shaderOverlay;

	Image ssaoNoiseImage = Image.CreateEmpty(4, 4, false, Image.Format.Rgb8);
	ImageTexture ssaoNoiseTexture;
	[Export]
	private int mode;


    public override void _Ready(){
		shaderOverlay = GetNode<Camera3D>("Camera").GetNode<MeshInstance3D>("SSAO");
		material = (ShaderMaterial)shaderOverlay.GetActiveMaterial(0);
		
		setssaoNoiseTexture();
		material.SetShaderParameter("noiseTexture",ssaoNoiseTexture);

		material.SetShaderParameter("mode",mode);
		//createRandomPoints(200,2.0f,1.0f);


	}

    public override void _Process(double delta){
		if (Input.IsActionJustPressed("esc")){
			GetTree().Quit(); 	
		}
		if (Input.IsActionJustPressed("1")){
			mode = 0;
			material.SetShaderParameter("mode",mode);
		}
		if (Input.IsActionJustPressed("2")){
			mode = 1;
			material.SetShaderParameter("mode",mode);
		}
		if (Input.IsActionJustPressed("3")){
			mode = 2;
			material.SetShaderParameter("mode",mode);
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