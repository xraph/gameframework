using UnrealBuildTool;
using System.Collections.Generic;

public class GameFrameworkProjectEditorTarget : TargetRules
{
    public GameFrameworkProjectEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V6;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("GameFrameworkProject");
    }
}
