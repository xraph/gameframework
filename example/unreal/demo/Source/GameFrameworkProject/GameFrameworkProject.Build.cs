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
            "FlutterPlugin",
            // FlutterGameMode parses and builds JSON directly. A monolithic
            // game target pulls these in through the plugin, so the omission
            // only shows up when the modular editor target tries to link.
            "Json",
            "JsonUtilities"
        });

        PrivateDependencyModuleNames.AddRange(new string[] { });
    }
}
