# This script packages the compiled Windows build files into a single, self-contained executable.
# It is executed automatically by CMake post-build in Release mode.

$projectDir = Resolve-Path $args[0]
$targetDir = Resolve-Path $args[1]
$config = $args[2]

# Only package for Release builds to prevent hot-reload and debugger attachment failures in Debug/Profile modes
if ($config -and $config -ne "Release") {
    Write-Host "=== Ricochet Packager: Skipped for $config configuration ==="
    exit 0
}

Write-Host "=========================================================="
Write-Host "=== Ricochet: Standalone Single-Binary Packager ==="
Write-Host "=========================================================="
Write-Host "Project Root: $projectDir"
Write-Host "Build Output: $targetDir"
Write-Host "Configuration: $config"

# Create a temporary directory for zipping target files
$tempPackName = "ricochet_pack_" + [Guid]::NewGuid().ToString("N")
$tempPackPath = Join-Path $env:TEMP $tempPackName
New-Item -ItemType Directory -Path $tempPackPath | Out-Null

# Copy all compiled Release files to the temporary folder
Copy-Item -Path "$targetDir\*" -Destination $tempPackPath -Recurse -Force

# Create payload.zip in the project root
$zipPath = Join-Path $projectDir "payload.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$tempPackPath\*" -DestinationPath $zipPath -Force

# Clean up temp packing folder
Remove-Item -Path $tempPackPath -Recurse -Force

# Configure compiler paths and inputs
$launcherCs = Join-Path $projectDir "windows\runner\Launcher.cs"
$iconPath = Join-Path $projectDir "windows\runner\resources\app_icon.ico"
$outputExe = Join-Path $targetDir "ricochet_standalone.exe"

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (Test-Path $csc) {
    Write-Host "Compiling Launcher wrapper embedding build payload..."
    & $csc /nologo /nowarn:1668 /target:winexe /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Windows.Forms.dll /resource:$zipPath /win32icon:$iconPath /out:$outputExe $launcherCs
    
    # Remove the temporary payload.zip
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    
    Write-Host "----------------------------------------------------------"
    Write-Host "Success: Standalone single-binary compiled cleanly!"
    Write-Host "Standalone Executable: $outputExe"
    Write-Host "=========================================================="
} else {
    Write-Warning "C# Compiler (csc.exe) was not found. Standalone packaging skipped."
}
