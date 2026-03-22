@echo off
setlocal enabledelayedexpansion

REM --- Configuration ---
SET PUBLISH_BASE=%TEMP%\publish-wj
SET CODE_SIGN_TOOL=%CODESIGNPATH%
SET COMMON_PUBLISH_ARGS=--runtime win-x64 --configuration Release /p:IncludeNativeLibrariesForSelfExtract=true --self-contained /p:DebugType=embedded

REM --- Check prerequisites ---
WHERE dotnet >nul 2>&1 || (
    echo .NET SDK not found. Please install the .NET SDK or add it to your PATH.
    exit /b 1
)

WHERE python >nul 2>&1 || (
    echo Python not found. Please install Python or add it to your PATH.
    exit /b 1
)

WHERE 7z >nul 2>&1
IF !ERRORLEVEL! EQU 0 (
    SET ZIPTOOL=7z
) ELSE IF EXIST "%ProgramFiles%\7-Zip\7z.exe" (
    SET ZIPTOOL="%ProgramFiles%\7-Zip\7z.exe"
) ELSE (
    echo 7-Zip not found. Please install 7-Zip or add it to your PATH.
    exit /b 1
)

REM --- Extract version ---
python scripts\version_extract.py > VERSION.txt
SET /p VERSION=<VERSION.txt
echo Building version: !VERSION!

REM --- Clean previous output ---
IF EXIST "!PUBLISH_BASE!\app" rmdir /q /s "!PUBLISH_BASE!\app"
IF EXIST "!PUBLISH_BASE!\launcher" rmdir /q /s "!PUBLISH_BASE!\launcher"
mkdir "!PUBLISH_BASE!"

REM --- Build ---
echo Cleaning solution...
dotnet clean || exit /b 1

echo Restoring packages...
dotnet restore --runtime win-x64 || exit /b 1

echo Publishing Wabbajack.App.Wpf...
dotnet publish Wabbajack.App.Wpf\Wabbajack.App.Wpf.csproj --framework "net9.0-windows" -o "!PUBLISH_BASE!\app" !COMMON_PUBLISH_ARGS! || exit /b 1

echo Publishing Wabbajack.Launcher...
dotnet publish Wabbajack.Launcher\Wabbajack.Launcher.csproj --framework "net9.0-windows" -o "!PUBLISH_BASE!\launcher" /p:PublishSingleFile=true !COMMON_PUBLISH_ARGS! || exit /b 1

echo Publishing Wabbajack.CLI...
dotnet publish Wabbajack.CLI\Wabbajack.CLI.csproj --framework "net9.0-windows" -o "!PUBLISH_BASE!\app\cli" !COMMON_PUBLISH_ARGS! || exit /b 1

REM --- Code signing ---
IF NOT DEFINED CODE_SIGN_TOOL (
    echo Code signing tool not found, skipping code signing.
    goto Package
)
IF NOT DEFINED CODE_SIGN_USER (
    echo CODE_SIGN_USER not set, skipping code signing.
    goto Package
)
IF NOT DEFINED CODE_SIGN_PASS (
    echo CODE_SIGN_PASS not set, skipping code signing.
    goto Package
)

echo Code signing files...
pushd "!CODE_SIGN_TOOL!"
call CodeSignTool.bat sign -input_file_path "!PUBLISH_BASE!\app\Wabbajack.exe" -username=!CODE_SIGN_USER! -password=!CODE_SIGN_PASS!
call CodeSignTool.bat sign -input_file_path "!PUBLISH_BASE!\launcher\Wabbajack.exe" -username=!CODE_SIGN_USER! -password=!CODE_SIGN_PASS!
call CodeSignTool.bat sign -input_file_path "!PUBLISH_BASE!\app\cli\wabbajack-cli.exe" -username=!CODE_SIGN_USER! -password=!CODE_SIGN_PASS!
popd

REM --- Package ---
:Package
echo Packaging !VERSION!.zip...
!ZIPTOOL! a "!PUBLISH_BASE!\!VERSION!.zip" "!PUBLISH_BASE!\app\*"
copy "!PUBLISH_BASE!\launcher\Wabbajack.exe" "!PUBLISH_BASE!\Wabbajack.exe"

echo Build complete: !PUBLISH_BASE!
