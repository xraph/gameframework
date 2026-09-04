using UnrealBuildTool;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

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
        // The two platforms ask for it differently. iOS reads bBuildAsFramework
        // from Config/DefaultEngine.ini and UEBuildIOS sets bShouldCompileAsDLL
        // itself; Mac has no such switch, so the target sets it here.
        //
        // Either way UBT objects, because the target changes a setting shared
        // with the engine's own build products, and it does not care whether
        // the project or the ini asked for it. bOverrideBuildEnvironment gets
        // past that; TargetBuildEnvironment.Unique is refused outright by an
        // installed engine.
        //
        // Read that as permission, not as a fix. An installed engine ships its
        // modules prebuilt, so on iOS BUILD_EMBEDDED_APP reaches this project
        // and not the engine, and the resulting framework links, launches, and
        // never boots an engine. Embedding needs the engine built from source.
        // Building a linkable dylib does not.
        if (Target.Platform == UnrealTargetPlatform.Mac ||
            Target.Platform == UnrealTargetPlatform.IOS)
        {
            bOverrideBuildEnvironment = true;
        }

        if (Target.Platform == UnrealTargetPlatform.Mac)
        {
            LinkType = TargetLinkType.Monolithic;
            bShouldCompileAsDLL = true;
        }

        if (Target.Platform == UnrealTargetPlatform.IOS)
        {
            AddSwiftCompatibilityLibraries(Target);
        }
    }

    /// Link the Swift back-deployment libraries by hand for a framework build.
    ///
    /// Engine and plugin Swift objects reference __swift_FORCE_LOAD_$_swiftCompatibility56,
    /// which lives in a static library shipped inside the Xcode toolchain. For a
    /// normal app Xcode drives the final link and adds that path itself. A
    /// framework build is linked by UnrealBuildTool directly, and
    /// AppleToolChain only adds the system /usr/lib/swift, not the toolchain's
    /// static compatibility libraries, so the link fails with undefined symbols.
    ///
    /// Nothing here is needed once UBT adds the path itself.
    private void AddSwiftCompatibilityLibraries(TargetInfo Target)
    {
        string ToolchainRoot = GetXcodeDeveloperDir();
        if (string.IsNullOrEmpty(ToolchainRoot))
        {
            return;
        }

        // The simulator has its own copy of these, and linking the device
        // ones into a simulator build fails on architecture.
        string SwiftPlatformDir =
            Target.Architectures.Contains(UnrealArch.IOSSimulator) ? "iphonesimulator" : "iphoneos";

        string SwiftLibDir = Path.Combine(ToolchainRoot,
            "Toolchains", "XcodeDefault.xctoolchain", "usr", "lib", "swift", SwiftPlatformDir);

        if (!Directory.Exists(SwiftLibDir))
        {
            return;
        }

        AdditionalLinkerArguments =
            (AdditionalLinkerArguments ?? "") +
            String.Format(" -L\"{0}\" -lswiftCompatibility56 -lswiftCompatibilityConcurrency", SwiftLibDir);
    }

    private string GetXcodeDeveloperDir()
    {
        try
        {
            ProcessStartInfo Info = new ProcessStartInfo("/usr/bin/xcode-select", "-p");
            Info.RedirectStandardOutput = true;
            Info.UseShellExecute = false;
            using (Process Proc = Process.Start(Info))
            {
                string Output = Proc.StandardOutput.ReadToEnd().Trim();
                Proc.WaitForExit();
                return Proc.ExitCode == 0 ? Output : "";
            }
        }
        catch (Exception)
        {
            return "";
        }
    }
}
