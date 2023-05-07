param (
    [switch]$ci = $false
)

function Try-Fetch-Deps {
    param ([String]$description)
    echo "Dependency '$description' was not found, running `tools/fetch_deps.py` to fetch any missing dependencies"
    if ((Get-Command "python" -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Host "python does not appear to be in your PATH. Please fix this or manually run tools\fetch_deps.py"
        exit 1
    } 
    python tools\fetch_deps.py
    if ($LASTEXITCODE -ne 0) {
        echo 'Error running fetch_deps.py'
        exit 1
    }
    else {
        echo 'Fetched deps successfully'
    }
}

try {
    # This assumes Visual Studio 2022 is installed in C:. You might have to change this depending on your system.
    # $DEFAULT_VS_PATH = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
    # $VS_PATH = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise"
    $VS_PATH = .\vswhere.exe -prerelease -latest -property installationPath

    if ( -not (Test-Path "$VS_PATH")) {
        echo "Error: VS_PATH isn't set correctly! Update the variable in build.ps1 for your system."
        echo "... or implement it properly with vswhere and submit a PR. (Please)"
        exit 1
    }

    if ( -not (Test-Path "Thirdparty\ACT\Advanced Combat Tracker.exe" )) {
        Try-Fetch-Deps -description "Advanced Combat Tracker.exe"
    }


    if ( -not (Test-Path "Thirdparty\FFXIV_ACT_Plugin\SDK\FFXIV_ACT_Plugin.Common.dll" )) {
        Try-Fetch-Deps -description "FFXIV_ACT_Plugin.Common.dll"
    }

    if ( -not (Test-Path "OverlayPlugin.Core\Thirdparty\FFXIVClientStructs\Base\Global" )) {
        Try-Fetch-Deps -description "FFXIVClientStructs"
    }

    $ENV:PATH = "$VS_PATH\MSBuild\Current\Bin;${ENV:PATH}";
    if (Test-Path "C:\Program Files\7-Zip\7z.exe") {
        $ENV:PATH = "C:\Program Files\7-Zip;${ENV:PATH}";
    }

    if (Test-Path "OverlayPlugin.Core\Thirdparty\FFXIVClientStructs\Base") {
        echo "==> Preparing FFXIVClientStructs..."
        
        echo "==> Building StripFFXIVClientStructs..."
        msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -t:StripFFXIVClientStructs -restore:True -v:q

        cd OverlayPlugin.Core\Thirdparty\FFXIVClientStructs\Base

        # Fix code to compile against .NET 4.8, remove partial funcs and helper funcs, we only want the struct layouts themselves
        gci * | foreach-object {
            $ns = $_.name

            echo "==> Stripping FFXIVClientStructs for namespace $ns..."

            ..\..\..\..\tools\StripFFXIVClientStructs\StripFFXIVClientStructs\bin\Release\netcoreapp3.1\StripFFXIVClientStructs.exe $ns .\$ns ..\Transformed\$ns
        }

        cd ..\..\..\..
            rm -ErrorAction SilentlyContinue -r $ns\*.csproj
            rm -ErrorAction SilentlyContinue -r $ns\*.sln
            rm -ErrorAction SilentlyContinue -r $ns\FFXIVClientStructs\GlobalUsings.cs
            rm -ErrorAction SilentlyContinue -r $ns\FFXIVClientStructs\Resolver.cs
            rm -ErrorAction SilentlyContinue -r $ns\FFXIVClientStructs\SigScanner.cs
            rm -ErrorAction SilentlyContinue -r $ns\FFXIVClientStructs\STD\Pair.cs
            rm -ErrorAction SilentlyContinue -r $ns\FFXIVClientStructs\FFXIV\Client\System\Memory
            rm -ErrorAction SilentlyContinue -r $ns\FFXIVClientStructs\STD\Pointer.cs
            rm -ErrorAction SilentlyContinue -r $ns\FFXIVClientStructs\STD\Span.cs

    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -t:Restore -v:q
    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -t:Clean -v:q
    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -v:q
                    $a = $_.fullname;
                    $b = ( get-content -Raw $a ) `
                    -replace '(?sm)^[\t ]+\[(?:MemberFunction|StaticAddress|VirtualFunction|FixedArray)[^\]]+\][\r?\n ][^;]+;(?: //[^\r?\n]+)?[ ]*\r?\n','' `
                    -replace '(?sm)^([\t ]+)public [^ ]+? [^ \r?\n]+?\([^\r?\n]+?\r?\n[ ]+?[^ ][^\x00]*?\r?\n\1\}\r?\n','' `
                    -replace '(?sm)^([\t ]+)public [^ ]+? this\[[^\r?\n]+?\r?\n[ ]+?[^ ][^\x00]*?\r?\n\1\}\r?\n','' `
                    -replace '(?sm)^([\t ]+)public [^ ]+? this\[[^\r?\n]+?\r?\n[^\x00]*?\r?\n\1\};\r?\n','' `
                    -replace '(?sm)^\[Addon\("[^\]]+"\)\]\r?\n','' `
                    -replace '(?sm)^\[Agent\([^\r?\n ]+\)\]\r?\n','' `
                    -replace '(?sm)^([\t ]+)public [^ ]+? [^ \r?\n]+?(?:\r?\n\1\{\r?\n\1\1get|[ ]?\{\r?\n\1\1get)[^\x00]\r?\n\1\}\r?\n','' `
                    -replace '(?sm)\[NoExport\] ','' `
                    -replace ('(?sm)namespace FFXIVClientStructs((?:\.FFXIV.*?|\.STD.*?|));([^\x00]*\r?\n\})\r?\n?'),(($globalUsings -replace '__NSREPLACE__',$ns)+"`nnamespace FFXIVClientStructs."+$ns+'$1 {$2}') `
                    -replace ('(?sm)using FFXIVClientStructs((?:\.FFXIV.*?|\.STD.*?|));'),("using FFXIVClientStructs."+$ns+'$1;') `
                    -replace '(?sm)\(([^ ]+) is (.*?) or (.*?)\)','($1 $2 || $1 $3)' `
                    -replace '(?sm)using CategoryMap = .*?;','' `
                    -replace '(?sm)hk[^ ]+\*','void*' `
                    -replace '(?sm)Pointer<[^>]+>','void*' `
                    -replace '(?sm)using FFXIVClientStructs.Havok;','' `
                    -replace '(?sm)\[FieldOffset\(0x0\)\] public CategoryMap\* MainMap;','' `
                    -replace '(?sm)public ([^\n]*?) ([^ ]+) => new\(','public $1 $2 => new $1(' `
                    -replace '(?sm)(\[FieldOffset\([^)]+\)\]) public delegate\*[^\n]+?([^ ]+);','$1 public void* $2;' `
                    -replace 'StdVector<void\*>','StdVector<long>' `
                    -replace 'public struct','public unsafe struct' `
                    -replace '(?:\t|    ).*?public LuaEventHandler LuaEventHandler;','' `
                    -replace 'StdMap<uint, void\*>','StdMap<uint, long>' `
                    -replace '(?sm)public static implicit operator (?:NumQuaternion|Matrix4x4|NumVector3).*?}','' `
                    -replace 'using (?:NumQuaternion|NumVector3) = System.Numerics.(?:Quaternion|Vector3);','' `
                    -replace 'StdMap<Utf8String, void\*>','StdMap<Utf8String, long>' `
                    -replace '(?sm)public static Utf8String\* FromString.*?\n(?:\t|    )}','' `
                    -replace ' : ICreatable','' `
                    -replace ('using FFXIVClientStructs.'+$ns+'.FFXIV.Client.System.Memory;'),'' `
                    -replace 'SkeletonResourceHandle\*\* SkeletonResourceHandles','long SkeletonResourceHandles' `
                    -replace 'StdMap<void\*, void\*>','StdMap<long, long>' `
                    -replace 'AtkLinkedList<void\*>','AtkLinkedList<long>' `
                    -replace 'public StatusManager\* GetStatusManager => Character.GetStatusManager\(\);','' `
                    -replace 'public Character.CastInfo\* GetCastInfo => Character.GetCastInfo\(\);','' `
                    -replace 'public Character.ForayInfo\* GetForayInfo => Character.GetForayInfo\(\);','' `
                    -replace '(?sm)public (?:ReadOnly)?Span<.*?\n(?:\t|    )\}','' `
                    -replace '(?sm)public static ulong GetBeastTribeAllowance.*?\n(?:\t|    )\}','' `
                    -replace '    public override string ToString\(\)\r?\n    \{\r?\n        return Encoding.UTF8.GetString\(GetBytes\(\)\);\r?\n    \}','' `
    & "C:\Program Files\7-Zip\7z.exe" a $archive OverlayPlugin
    7z a $archive OverlayPlugin

    cd ..\..
                    -replace '(StdVector|StdDeque|StdMap|CVector)<[^>]+>','$1' `
                    -replace 'public Span<ActionBarSlot> Slot => new Span<ActionBarSlot>\(ActionBarSlots, SlotCount\);','' `
                    -replace 'AtkLinkedList<long>','AtkLinkedList' `
                    -replace 'public [^\n]+ => (?!new).*?;','' `
                    -replace '(?sm)public static Agent[A-Za-z]+\* Instance.*?\n(?:\t|    )\}','' `
                    -replace '(?sm)public void OpenRecipeByRecipeId.*?;','' `
                    -replace '(?sm)public static void PlayChatSoundEffect.*?\n(?:\t|    )\}','' `
                    -replace '(?sm)public string Comment \{.*?\n(?:\t|    ){2}\}','' `
                    -replace '(?sm)public static (?:ConfigModule|RaptureGearsetModule)\* Instance.*?\n(?:\t|    )\}',''

                    $b | set-content $a
                }

            # Clean up the STD namespace objects
            (get-content ..\..\MemoryProcessors\AtkStage\FFXIVClientStructs\Templates\STD.Map.cs) -replace '__NAMESPACE__',$ns | set-content $ns\FFXIVClientStructs\STD\Map.cs
            (get-content ..\..\MemoryProcessors\AtkStage\FFXIVClientStructs\Templates\STD.Deque.cs) -replace '__NAMESPACE__',$ns | set-content $ns\FFXIVClientStructs\STD\Deque.cs
            (get-content ..\..\MemoryProcessors\AtkStage\FFXIVClientStructs\Templates\STD.Vector.cs) -replace '__NAMESPACE__',$ns | set-content $ns\FFXIVClientStructs\STD\Vector.cs
            (get-content ..\..\MemoryProcessors\AtkStage\FFXIVClientStructs\Templates\FFXIV.Component.GUI.AtkLinkedList.cs) -replace '__NAMESPACE__',$ns | set-content $ns\FFXIVClientStructs\FFXIV\Component\GUI\AtkLinkedList.cs
            }

        cd ..\..\..
    }

    if ( -not (Test-Path .\OverlayPlugin.Updater\Resources\libcurl.dll)) {
        echo "==> Building cURL..."

        mkdir .\OverlayPlugin.Updater\Resources
        cd Thirdparty\curl\winbuild

        echo "@call `"$VS_PATH\VC\Auxiliary\Build\vcvarsall.bat`" amd64"           | Out-File -Encoding ascii tmp_build.bat
        echo "nmake /f Makefile.vc mode=dll VC=16 GEN_PDB=no DEBUG=no MACHINE=x64" | Out-File -Encoding ascii -Append tmp_build.bat
        echo "@call `"$VS_PATH\VC\Auxiliary\Build\vcvarsall.bat`" x86"             | Out-File -Encoding ascii -Append tmp_build.bat
        echo "nmake /f Makefile.vc mode=dll VC=16 GEN_PDB=no DEBUG=no MACHINE=x86" | Out-File -Encoding ascii -Append tmp_build.bat

        cmd "/c" "tmp_build.bat"
        sleep 3
        del tmp_build.bat

        cd ..\builds
        copy .\libcurl-vc16-x64-release-dll-ipv6-sspi-winssl\bin\libcurl.dll ..\..\..\OverlayPlugin.Updater\Resources\libcurl-x64.dll
        copy .\libcurl-vc16-x86-release-dll-ipv6-sspi-winssl\bin\libcurl.dll ..\..\..\OverlayPlugin.Updater\Resources\libcurl.dll

        cd ..\..\..
    }

    if ($ci) {
        echo "==> Continuous integration flag set. Building Debug..."
        msbuild -p:Configuration=Debug -p:Platform=x64 "OverlayPlugin.sln" -t:Restore
        msbuild -p:Configuration=Debug -p:Platform=x64 "OverlayPlugin.sln"    
    }

    echo "==> Building..."

    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -t:Restore
    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln"
    if (-not $?) { exit 1 }

    echo "==> Building archive..."

    cd out\Release

    if (Test-Path OverlayPlugin) { rm -Recurse OverlayPlugin }
    mkdir OverlayPlugin\libs

    cp @("OverlayPlugin.dll", "OverlayPlugin.dll.config", "README.md", "LICENSE.txt") OverlayPlugin
    cp -Recurse libs\resources OverlayPlugin
    cp -Recurse libs\*.dll OverlayPlugin\libs
    del OverlayPlugin\libs\CefSharp.*

    # Translations
    cp -Recurse @("de-DE", "fr-FR", "ja-JP", "ko-KR", "zh-CN") OverlayPlugin
    cp -Recurse @("libs\de-DE", "libs\fr-FR", "libs\ja-JP", "libs\ko-KR", "libs\zh-CN") OverlayPlugin\libs


    $text = [System.IO.File]::ReadAllText("$PWD\..\..\SharedAssemblyInfo.cs");
    $regex = [regex]::New('\[assembly: AssemblyVersion\("([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+"\)');
    $m = $regex.Match($text);

    if (-not $m) {
        echo "Error: Version number not found in the AssemblyInfo.cs!"
        exit 1
    }

    $version = $m.Groups[1]
    $archive = "..\OverlayPlugin-$version.7z"

    if (Test-Path $archive) { rm $archive }
    cd OverlayPlugin
    & "C:\Program Files\7-Zip\7z.exe" a ..\$archive .
    cd ..

    $archive = "..\OverlayPlugin-$version.zip"

    if (Test-Path $archive) { rm $archive }
    7z a $archive OverlayPlugin
} catch {
    Write-Error $Error[0]
}
