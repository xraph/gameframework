#include "RotatingCube.h"
#include "FlutterBridge.h"
#include "Components/StaticMeshComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Engine/StaticMesh.h"
#include "UObject/ConstructorHelpers.h"
#include "TimerManager.h"

ARotatingCube::ARotatingCube()
{
    PrimaryActorTick.bCanEverTick = true;

    // Create cube mesh component
    CubeMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CubeMesh"));
    RootComponent = CubeMesh;

    // Set default cube mesh
    static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMeshAsset(TEXT("/Engine/BasicShapes/Cube"));
    if (CubeMeshAsset.Succeeded())
    {
        CubeMesh->SetStaticMesh(CubeMeshAsset.Object);
    }

    // Set default values
    FlutterTargetName = TEXT("RotatingCube");
    bAutoRegister = true;
}

void ARotatingCube::BeginPlay()
{
    Super::BeginPlay();

    // Create dynamic material
    if (CubeMesh && CubeMesh->GetMaterial(0))
    {
        DynamicMaterial = CubeMesh->CreateAndSetMaterialInstanceDynamic(0);
        UpdateMaterialColor();
    }

    // Notify Flutter that we're ready
    SendToFlutter(TEXT("onReady"), TEXT("true"));

    // Set up auto-sync timer if enabled
    if (SyncIntervalSeconds > 0.0f)
    {
        GetWorldTimerManager().SetTimer(
            SyncTimerHandle,
            this,
            &ARotatingCube::SyncStateToFlutter,
            SyncIntervalSeconds,
            true
        );
    }

    UE_LOG(LogTemp, Log, TEXT("[RotatingCube] BeginPlay - Speed: %.1f, Axis: %s"), 
        RotationSpeed, *RotationAxis.ToString());
}

void ARotatingCube::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    if (bIsRotating && RotationSpeed != 0.0f)
    {
        // Calculate rotation delta
        float DeltaRotation = RotationSpeed * DeltaTime;
        CurrentRotationAngle += DeltaRotation;

        // Wrap angle
        if (CurrentRotationAngle > 360.0f) CurrentRotationAngle -= 360.0f;
        if (CurrentRotationAngle < -360.0f) CurrentRotationAngle += 360.0f;

        // Apply rotation
        FRotator DeltaRotator = FRotator::ZeroRotator;
        if (RotationAxis.X != 0.0f) DeltaRotator.Roll = DeltaRotation * RotationAxis.X;
        if (RotationAxis.Y != 0.0f) DeltaRotator.Pitch = DeltaRotation * RotationAxis.Y;
        if (RotationAxis.Z != 0.0f) DeltaRotator.Yaw = DeltaRotation * RotationAxis.Z;

        AddActorLocalRotation(DeltaRotator);
    }
}

FString ARotatingCube::GetFlutterTargetName() const
{
    // Use a specific name for the rotating cube demo
    return TEXT("GameFrameworkDemo");
}

void ARotatingCube::OnFlutterMessage_Implementation(const FString& Method, const FString& Data)
{
    UE_LOG(LogTemp, Log, TEXT("[RotatingCube] Message: %s(%s)"), *Method, *Data);

    if (Method == TEXT("setSpeed"))
    {
        float NewSpeed = FCString::Atof(*Data);
        SetSpeed(NewSpeed);
    }
    else if (Method == TEXT("setAxis"))
    {
        FVector NewAxis = ParseAxisFromJson(Data);
        SetAxis(NewAxis);
    }
    else if (Method == TEXT("setColor"))
    {
        FLinearColor NewColor = ParseColorFromJson(Data);
        SetColor(NewColor);
    }
    else if (Method == TEXT("reset"))
    {
        Reset();
    }
    else if (Method == TEXT("getState"))
    {
        SyncStateToFlutter();
    }
    else if (Method == TEXT("setRotating"))
    {
        bool bRotate = Data.ToBool();
        SetRotating(bRotate);
    }
    else
    {
        UE_LOG(LogTemp, Warning, TEXT("[RotatingCube] Unknown method: %s"), *Method);
    }
}

void ARotatingCube::SetSpeed(float NewSpeed)
{
    RotationSpeed = FMath::Clamp(NewSpeed, -360.0f, 360.0f);
    
    // Notify Blueprint
    OnSpeedChanged_Blueprint(RotationSpeed);

    // Notify Flutter
    FString JsonData = FString::Printf(TEXT("{\"speed\":%.1f,\"rpm\":%.2f}"), RotationSpeed, GetRPM());
    SendToFlutter(TEXT("onSpeedChanged"), JsonData);

    UE_LOG(LogTemp, Log, TEXT("[RotatingCube] Speed set to: %.1f"), RotationSpeed);
}

void ARotatingCube::SetAxis(FVector NewAxis)
{
    RotationAxis = NewAxis.GetSafeNormal();
    
    // Notify Blueprint
    OnAxisChanged_Blueprint(RotationAxis);

    // Notify Flutter
    FString JsonData = FString::Printf(TEXT("{\"x\":%.2f,\"y\":%.2f,\"z\":%.2f}"), 
        RotationAxis.X, RotationAxis.Y, RotationAxis.Z);
    SendToFlutter(TEXT("onAxisChanged"), JsonData);

    UE_LOG(LogTemp, Log, TEXT("[RotatingCube] Axis set to: %s"), *RotationAxis.ToString());
}

void ARotatingCube::SetColor(FLinearColor NewColor)
{
    CubeColor = NewColor;
    UpdateMaterialColor();
    
    // Notify Blueprint
    OnColorChanged_Blueprint(CubeColor);

    // Notify Flutter
    FString JsonData = FString::Printf(TEXT("{\"r\":%.2f,\"g\":%.2f,\"b\":%.2f,\"a\":%.2f}"),
        CubeColor.R, CubeColor.G, CubeColor.B, CubeColor.A);
    SendToFlutter(TEXT("onColorChanged"), JsonData);

    UE_LOG(LogTemp, Log, TEXT("[RotatingCube] Color set to: %s"), *CubeColor.ToString());
}

void ARotatingCube::Reset()
{
    RotationSpeed = DefaultSpeed;
    RotationAxis = DefaultAxis;
    CubeColor = DefaultColor;
    CurrentRotationAngle = 0.0f;
    bIsRotating = true;

    // Reset rotation
    SetActorRotation(FRotator::ZeroRotator);

    // Update material
    UpdateMaterialColor();

    // Notify Blueprint
    OnReset_Blueprint();

    // Notify Flutter
    SendToFlutter(TEXT("onReset"), GetStateJson());

    UE_LOG(LogTemp, Log, TEXT("[RotatingCube] Reset to defaults"));
}

FString ARotatingCube::GetStateJson() const
{
    return FString::Printf(
        TEXT("{\"speed\":%.1f,\"rpm\":%.2f,\"axis\":{\"x\":%.2f,\"y\":%.2f,\"z\":%.2f},")
        TEXT("\"color\":{\"r\":%.2f,\"g\":%.2f,\"b\":%.2f,\"a\":%.2f},")
        TEXT("\"rotation\":%.1f,\"isRotating\":%s}"),
        RotationSpeed,
        GetRPM(),
        RotationAxis.X, RotationAxis.Y, RotationAxis.Z,
        CubeColor.R, CubeColor.G, CubeColor.B, CubeColor.A,
        CurrentRotationAngle,
        bIsRotating ? TEXT("true") : TEXT("false")
    );
}

void ARotatingCube::SetRotating(bool bShouldRotate)
{
    bIsRotating = bShouldRotate;

    FString JsonData = FString::Printf(TEXT("{\"isRotating\":%s}"), bShouldRotate ? TEXT("true") : TEXT("false"));
    SendToFlutter(TEXT("onRotatingChanged"), JsonData);
}

float ARotatingCube::GetRPM() const
{
    // Degrees per second to RPM
    return RotationSpeed / 6.0f; // 360 degrees = 60 seconds for 1 RPM
}

void ARotatingCube::SyncStateToFlutter()
{
    SendToFlutter(TEXT("onState"), GetStateJson());
}

void ARotatingCube::UpdateMaterialColor()
{
    if (DynamicMaterial)
    {
        DynamicMaterial->SetVectorParameterValue(TEXT("BaseColor"), CubeColor);
    }
}

FVector ARotatingCube::ParseAxisFromJson(const FString& JsonData)
{
    FVector Result = FVector(0.0f, 1.0f, 0.0f);

    // Simple JSON parsing (for production, use FJsonSerializer)
    float X = 0.0f, Y = 1.0f, Z = 0.0f;
    
    // Find x value
    int32 XStart = JsonData.Find(TEXT("\"x\":"));
    if (XStart != INDEX_NONE)
    {
        FString XStr = JsonData.Mid(XStart + 4, 10);
        X = FCString::Atof(*XStr);
    }

    // Find y value
    int32 YStart = JsonData.Find(TEXT("\"y\":"));
    if (YStart != INDEX_NONE)
    {
        FString YStr = JsonData.Mid(YStart + 4, 10);
        Y = FCString::Atof(*YStr);
    }

    // Find z value
    int32 ZStart = JsonData.Find(TEXT("\"z\":"));
    if (ZStart != INDEX_NONE)
    {
        FString ZStr = JsonData.Mid(ZStart + 4, 10);
        Z = FCString::Atof(*ZStr);
    }

    Result = FVector(X, Y, Z);
    return Result;
}

FLinearColor ARotatingCube::ParseColorFromJson(const FString& JsonData)
{
    FLinearColor Result = FLinearColor::White;

    float R = 1.0f, G = 1.0f, B = 1.0f, A = 1.0f;

    // Find r value
    int32 RStart = JsonData.Find(TEXT("\"r\":"));
    if (RStart != INDEX_NONE)
    {
        FString RStr = JsonData.Mid(RStart + 4, 10);
        R = FCString::Atof(*RStr);
    }

    // Find g value
    int32 GStart = JsonData.Find(TEXT("\"g\":"));
    if (GStart != INDEX_NONE)
    {
        FString GStr = JsonData.Mid(GStart + 4, 10);
        G = FCString::Atof(*GStr);
    }

    // Find b value
    int32 BStart = JsonData.Find(TEXT("\"b\":"));
    if (BStart != INDEX_NONE)
    {
        FString BStr = JsonData.Mid(BStart + 4, 10);
        B = FCString::Atof(*BStr);
    }

    // Find a value
    int32 AStart = JsonData.Find(TEXT("\"a\":"));
    if (AStart != INDEX_NONE)
    {
        FString AStr = JsonData.Mid(AStart + 4, 10);
        A = FCString::Atof(*AStr);
    }

    Result = FLinearColor(R, G, B, A);
    return Result;
}
