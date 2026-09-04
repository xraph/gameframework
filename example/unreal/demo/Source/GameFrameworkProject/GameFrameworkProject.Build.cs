using UnrealBuildTool;

public class GameFrameworkProject : ModuleRules
{
    public GameFrameworkProject(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[] { 
            "Core", 
            "CoreUObject", 
            "Engine", 
            "InputCore",
            "FlutterPlugin"
        });

        PrivateDependencyModuleNames.AddRange(new string[] { });
    }
}
