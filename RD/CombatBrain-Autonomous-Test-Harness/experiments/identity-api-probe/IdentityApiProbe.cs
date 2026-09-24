using System.Reflection;
using TaleWorlds.Library;
using TaleWorlds.ModuleManager;
using TaleWorlds.MountAndBlade;

public static class IdentityApiProbe
{
    public static string Probe()
    {
        var av = ApplicationVersion.FromParametersFile();
        _ = av.ApplicationVersionType;
        _ = av.Major;
        _ = av.Minor;
        _ = av.Revision;
        _ = av.ChangeSet;
        _ = ModuleHelper.GetActiveModules();
        _ = ModuleHelper.GetModuleFullPath("Native");
        var m = ModuleHelper.GetModules();
        foreach (var mm in m) _ = mm.Id;
        var asm = Assembly.GetExecutingAssembly();
        _ = asm.ManifestModule.ModuleVersionId;
        _ = asm.Location;
        Debug.Print("cbath-probe");
        InformationManager.DisplayMessage(new InformationMessage("cbath-probe"));
        return av.ToString();
    }
}
