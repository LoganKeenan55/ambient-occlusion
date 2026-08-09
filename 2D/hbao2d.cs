using Godot;

public partial class hbao2d : Node2D
{
    private Node2D target;
	private Sprite2D center;
	private Sprite2D wall;
	private Sprite2D blackSqaure;
	private bool showColor = false;

    public override void _Ready(){
		target = GetNode<Node2D>("Wall/Corner");
		center = GetNode<Sprite2D>("Sqaure");
		wall = GetNode<Sprite2D>("Wall");
		blackSqaure = GetNode<Sprite2D>("BlackSqaure");
		
		Input.MouseMode = Input.MouseModeEnum.Hidden;


		Color color = blackSqaure.Modulate;
		color.A = 0.0f;
		blackSqaure.Modulate = color;

    }


    public override void _Process(double delta){
		if (Input.IsActionJustPressed("esc")){
			GetTree().Quit(); 
		}
		    wall.GlobalPosition = GetGlobalMousePosition();

		QueueRedraw();

		if (Input.IsActionJustPressed("space")){
			showColor = true;
		}

		if (!showColor){
			return;
		}
		float elevation = Mathf.Atan2(
			-(target.GlobalPosition.Y - center.GlobalPosition.Y),
			Mathf.Abs(target.GlobalPosition.X - center.GlobalPosition.X)
		);

		float occlusion = Mathf.Sin(elevation);
		occlusion = Mathf.Pow(occlusion, 0.5f);
		occlusion = Mathf.Clamp(occlusion, 0.0f, 1.0f);

		Color color = blackSqaure.Modulate;
		color.A = occlusion;
		blackSqaure.Modulate = color;

    }

    public override void _Draw()
    {
        if (target == null)
            return;


        DrawLine(
            center.GlobalPosition,
            target.GlobalPosition,
            new Color("#ff4e4e"),
            7.0f
        );
    }
}