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
        # Disable for CN
        # Try-Fetch-Deps -description "FFXIVClientStructs"
    }

    $ENV:PATH = "$VS_PATH\MSBuild\Current\Bin;${ENV:PATH}";
    if (Test-Path "C:\Program Files\7-Zip\7z.exe") {
        $ENV:PATH = "C:\Program Files\7-Zip;${ENV:PATH}";
    }
    # Disable for CN
    if (False) {
    #if (Test-Path "OverlayPlugin.Core\Thirdparty\FFXIVClientStructs\Base") {
        echo "==> Preparing FFXIVClientStructs..."

        echo "==> Building StripFFXIVClientStructs..."
        msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -t:StripFFXIVClientStructs -restore:True -v:q

        cd OverlayPlugin.Core\Thirdparty\FFXIVClientStructs\Base

        # Fix code to compile against .NET 4.8, remove partial funcs and helper funcs, we only want the struct layouts themselves
        gci * | foreach-object {
            $ns = $_.name

            echo "==> Stripping FFXIVClientStructs for namespace $ns..."

            ..\..\..\..\tools\StripFFXIVClientStructs\StripFFXIVClientStructs\bin\Release\net6.0\StripFFXIVClientStructs.exe $ns .\$ns ..\Transformed\$ns
        }

        cd ..\..\..\..
    }

    if ($ci) {
        echo "==> Continuous integration flag set. Building Debug..."
        msbuild -p:Configuration=Debug -p:Platform=x64 "OverlayPlugin.sln" -t:Restore
        msbuild -p:Configuration=Debug -p:Platform=x64 "OverlayPlugin.sln" -t:Clean
        msbuild -p:Configuration=Debug -p:Platform=x64 "OverlayPlugin.sln"    
    }

    echo "==> Building..."

    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -t:Restore -v:q
    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -t:Clean -v:q
    msbuild -p:Configuration=Release -p:Platform=x64 "OverlayPlugin.sln" -v:q
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
    & 7z a ..\$archive .
    cd ..

    $archive = "..\OverlayPlugin-$version.zip"

    if (Test-Path $archive) { rm $archive }
    7z a $archive OverlayPlugin

    cd ..\..
} catch {
    Write-Error $Error[0]
}
