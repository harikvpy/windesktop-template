param (
    [switch]$skipVersionIncr = $false,
    [switch]$skipGitCommit = $false
)
function replaceVersionStr($file, $curStr, $newStr) {
    Write-Host -NoNewline "Replacing $curStr with $newStr in $file..."
    (Get-Content $file).replace($curStr, $newStr) | Set-Content $file
    Write-Host "done."
}

# Check if there are pending changes to be committed. Source tree has
# to be clean meaning all changes should be commited to repo before
# build can proceed.
if (!$skipGitCommit) {
    git diff --exit-code | Out-Null
    if (!$?) {
        Write-Output "There are pending changes to be commited."
        exit 1
    }
    git diff --cached --exit-code | Out-Null
    if (!$?) {
        Write-Output "There are pending changes to be commited."
        exit 1
    }
}

$version = Get-Content 'version.ini'  |Where-Object { $_ -match 'version=' }
$version = $version.Split('=')[1]
$major = [int]$version.Split(".")[0]
$minor = [int]$version.Split(".")[1]
$build = [int]$version.Split(".")[2]
# Increment build bumber
$newBuild = $build + 1
$newVerStr = "$major.$minor.$newBuild"
Write-Output "Building $newVerStr..."
Write-Output "Replacing version strings in relevant files..."
# $wxsFiles = @(".\productmsi\Product.wxs", ".\setup\Bundle.wxs")
# for ($i=0; $i -lt $wxsFiles.length; $i++) {
#     $file = $wxsFiles[$i]
#     (Get-Content $file) -replace "PRODUCT_VERSION=\d+\.\d+\.\d+", "PRODUCT_VERSION=$major.$minor.$newBuild" | Out-File $file
# }

# Update rc file
$rcfile = ".\helloworld\helloworld.rc"
(Get-Content $rcfile) -replace "FILEVERSION(\s+)\d+,\d+,\d+,\d+", "FILEVERSION 0,$major,$minor,$newBuild" | Out-File $rcfile
(Get-Content $rcfile) -replace "PRODUCTVERSION(\s+)\d+,\d+,\d+,\d+", "PRODUCTVERSION 0,$major,$minor,$newBuild" | Out-File $rcfile
(Get-Content $rcfile) -replace "`"FileVersion`",(\s+)`"\d+.\d+.\d+.\d+`"", "`"FileVersion`", `"0.$major.$minor.$newBuild`"" | Out-File $rcfile
(Get-Content $rcfile) -replace "`"ProductVersion`",(\s+)`"\d+.\d+.\d+.\d+`"", "`"ProductVersion`", `"0.$major.$minor.$newBuild`"" | Out-File $rcfile
# Generate version.h so that About Box will reflect correct version
Set-Content .\helloworld\version.h "#pragma once`r`n`r`n#define VERSION `"$major.$minor.$newBuild`"`r`n"

# Set environment variable for WiX scripts
$env:PRODUCT_VERSION="$newVerStr"

if (!$skipVersionIncr) {
    Write-Output "Updating version.ini..."
    Set-Content -path version.ini "version=$major.$minor.$newBuild`r`n"
} else {
    Write-Output "Skipping version increment."
}

Write-Output "Starting build.."
# Setup Visual Studio environment
& .\vs2019.ps1
# Regenerate deps.wxs
$heat = $env:WIX + "bin\heat.exe"
Push-Location .\setup
& $heat dir ..\deps\ -cg ProgramDependencies -ke -dr INSTALLFOLDER -gg -g1 -sfrag -srd -out deps.wxs -swall -var var.DependenciesFolder
Pop-Location

# Kick off build, x64 first
msbuild .\windesktop-wix-template.sln /p:Configuration=Release /p:Platform=x64
if (!($LastExitCode -eq 0)) {
    Write-Output "Error in building.."
    exit 1
}
# x86 (Win32) next
msbuild .\windesktop-wix-template.sln /p:Configuration=Release /p:Platform=x86
if (!($LastExitCode -eq 0)) {
    Write-Output "Error in building.."
    exit 1
}

# Append version to setup output.
$setupFile = ".\setup_bootstrapper\bin\Release\helloworldsetup.exe"
if (!(Test-Path -Path .\dist)) { mkdir .\dist | Out-Null }
if (!(Test-Path -Path .\dist\Release)) { mkdir .\dist\Release | Out-Null }

$setupFileWithVersion = ".\dist\Release\helloworldsetup_$newVerStr.exe"
Copy-Item $setupFile $setupFileWithVersion
$tag = "v$newVerStr"
Write-Output "Solution built."
# Tag git
if (!$skipGitCommit) {
    Write-Output "Committing & tagging as '$tag'"
    git commit -a -m "Release v$newVerStr"
    git tag $tag
    # git push origin
    # git push origin --tags
} else {
    Write-Output "Skipping committing & tagging"
}
Write-Output "Done."

