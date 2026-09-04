using UnrealBuildTool;
using System.Collections.Generic;

public class GameFrameworkProjectTarget : TargetRules
{
    public GameFrameworkProjectTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V6;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("GameFrameworkProject");

        // Build as a dynamic library so a Flutter host can link the result.
        //
        // iOS drives this from Config/DefaultEngine.ini instead, where
        // bBuildAsFramework under IOSRuntimeSettings makes UEBuildIOS set
        // bShouldCompileAsDLL for us. Mac has no equivalent switch, so the
        // target asks directly.
        //
        // The unique build environment is required: without it UBT refuses,
        // because the project would be changing a setting it shares with the
        // installed engine's own build products.
        if (Target.Platform == UnrealTargetPlatform.Mac)
        {
            LinkType = TargetLinkType.Monolithic;
            bOverrideBuildEnvironment = true;
            bShouldCompileAsDLL = true;
        }
    }
}
