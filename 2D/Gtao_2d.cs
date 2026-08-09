using Godot;

public partial class Gtao_2d : Node2D
{
    private Node2D corner1;
    private Node2D corner2;

    private Sprite2D center;
    private Sprite2D wall;
    private Sprite2D wall2;
    private Sprite2D blackSqaure;

    private bool movingWall1 = true;

    const float HALF_PI = Mathf.Pi / 2.0f;

    public override void _Ready(){
        corner1 = GetNode<Node2D>("Wall/Corner");
        corner2 = GetNode<Node2D>("Wall2/Corner2");

        center = GetNode<Sprite2D>("Sqaure");

        wall = GetNode<Sprite2D>("Wall");
        wall2 = GetNode<Sprite2D>("Wall2");

        blackSqaure = GetNode<Sprite2D>("BlackSqaure");

        Input.MouseMode = Input.MouseModeEnum.Captured;

        Color color = blackSqaure.Modulate;
        color.A = 0.0f;
        blackSqaure.Modulate = color;
    }

    public override void _Input(InputEvent @event){
        if (@event is InputEventMouseMotion motion)
        {
            if (movingWall1)
                wall.GlobalPosition += motion.Relative;
            else
                wall2.GlobalPosition += motion.Relative;
        }
    }

    public override void _Process(double delta){
        if (Input.IsActionJustPressed("esc"))
            GetTree().Quit();

        if (Input.IsActionJustPressed("space"))
            movingWall1 = !movingWall1;

        QueueRedraw();

        float leftElevation = Mathf.Atan2(
            -(corner1.GlobalPosition.Y - center.GlobalPosition.Y),
            Mathf.Abs(corner1.GlobalPosition.X - center.GlobalPosition.X)
        );

        float rightElevation = Mathf.Atan2(
            -(corner2.GlobalPosition.Y - center.GlobalPosition.Y),
            Mathf.Abs(corner2.GlobalPosition.X - center.GlobalPosition.X)
        );

		float leftOcclusion = Mathf.Clamp(leftElevation, 0f, HALF_PI);
		float rightOcclusion = Mathf.Clamp(rightElevation, 0f, HALF_PI);

		float visibility = 0.5f * (Mathf.Cos(leftOcclusion) + Mathf.Cos(rightOcclusion));
		visibility = Mathf.Clamp(visibility, 0.0f, 1.0f);

        Color color = blackSqaure.Modulate;
        color.A = 1.0f - visibility;
        blackSqaure.Modulate = color;
    }

    public override void _Draw(){
        if (corner1 == null || corner2 == null)
            return;

        DrawLine(
            center.GlobalPosition,
            corner1.GlobalPosition,
            Colors.Red,
            7.0f
        );

        DrawLine(
            center.GlobalPosition,
            corner2.GlobalPosition,
            Colors.DeepSkyBlue,
            7.0f
        );
    }
}