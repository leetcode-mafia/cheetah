public class ModerationResponse
{
    public string Id { get; set; }
    public string Model { get; set; }
    public List<ModerationResult> Results { get; set; }
}

public class ModerationResult
{
    public Categories Categories { get; set; }
    public CategoryScores Category_Scores { get; set; }
    public bool Flagged { get; set; }
}

public class Categories
{
    public bool Hate { get; set; }
    public bool Self_Harm { get; set; }
    public bool Violence { get; set; }
}

public class CategoryScores
{
    public float Hate { get; set; }
    public float Self_Harm { get; set; }
    public float Violence { get; set; }
}