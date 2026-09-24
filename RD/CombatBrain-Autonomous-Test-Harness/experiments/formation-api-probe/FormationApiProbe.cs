using TaleWorlds.MountAndBlade;

public static class FormationApiProbe
{
    public static int CountAllFormations()
    {
        var mission = Mission.Current;
        if (mission == null) return 0;
        var count = 0;
        foreach (var team in mission.Teams)
        foreach (var formation in team.FormationsIncludingEmpty)
        {
            if (formation.CountOfUnits == 0) continue;
            _ = team.TeamIndex;
            _ = team.Side;
            _ = formation.RepresentativeClass;
            _ = formation.FormationIndex;
            _ = formation.IsAIControlled;
            _ = formation.CurrentPosition;
            _ = formation.Direction;
            _ = OrderController.GetActiveMovementOrderOf(formation);
            _ = OrderController.GetActiveArrangementOrderOf(formation);
            _ = OrderController.GetActiveFiringOrderOf(formation);
            count++;
        }
        return count;
    }
}


