using Godot;

public partial class Main : Node3D
{

    public override void _Ready(){
	}

    public override void _Process(double delta){
		if (Input.IsActionJustPressed("esc")){
			GetTree().Quit(); 
		}
    }


}