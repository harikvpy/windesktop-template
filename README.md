# What is this
A Visual Studio 2019 solution template for a vanilla Windows Desktop application with integrated WiX projects to generate distributable MSI of the application. Also included is a WiX bootstrapper project that installs the VC redistributable component before starting the product MSI installation.

# Dependencies
* [Visual Studion 2019 (Any Edition)](https://visualstudio.microsoft.com/downloads/)
* [WiX Toolset v3.x](https://wixtoolset.org/)
* [Git](https://git-scm.com/) tool in Path.

# Contents
Project/Script | Description
--------|------------
helloworld | The Windows Desktop application
setup | WiX project to generate the MSI for the above
setup_bootstrapper | WiX project for bootstrapper
build.ps1 | A PowerShell script to automate the build process
vs2019.ps1 | A PowerShell script to setup Visual Studio 2019 development environment

# Details
## Application
This is a plain Windows Desktop application, generated using the Visual Studio Desktop Application wizard. One key point is that the application dynamically links to VC runtime library. Therefore an installer for this  app would require the VC runtime to be installed as a pre-requisite.

## MSI Installer
Installer is slightly more complex than the application above. It has to cater for installing to both Win32 & x64 platforms with separate binaries. Also the target Program Files folder is different for these two platforms. The WiX project handles this by using WiX pre-processor variables.

Specifically the installer does the following:
* Has a mock software license file in License.rtf
* Installs `helloworld.exe` to ProgramFilesFolder\SmallPearl\HelloWorld
* Creates an application shortcut in Start Menu
* Handles upgrade via an UpgradeCode.

## MSI Bootstrapper
This essentially bundles the x64 & x86 MSI files from above with the relevant VC Runtime redistributables. Both the MSI files are packaged and depending on the platform bitness, the appropriate MSI is installed. The same goes for the VC Runtime redistributable as well.

Note that the MSI file paths are hardcoded into `Bundle.wxs`. When adapting this code for a project, make sure to update these to the correct path for your project (as you are more than likely to rename `helloworld` to something different).

## Build Script
Build.ps1 is a PowerShell script that can be used to automate the build process. The script does the following:
* Chceks if there are any pending changes to be committed. If there are, script wouldn't proceed.
* Reads the product version from `version.ini`, increments it and updates the following files:
  * WiX scripts - `product.wxs` & `bundle.wxs`.
  * Version information in `helloworld` resource file
* Saves the new version in `version.ini`
* Sets up build environment by invoking `vs2019.ps1`
* Launches `msbuild` to build the 32-bit and 64-bit binaries & MSI files
* Builds the MSI bootstrapper & copies it to `dist\Release` folder, appending the version to the filename.
* Commits & tags all changes. Tag is of the format `v<major>.<minor>.<build>`

# Things to Change
* Change project `helloworld` to something else.
* Change `ProductCode` & `UpgradeCode` GUIDs in `Product.wxs`.
* Change `UpgradeCode` in `Bundle.wxs`.

# References
* VC Redist Bootstrapper is a direct copy of the gist [here](https://gist.github.com/nathancorvussolis/6852ba282647aeb0c5c00e742e28eb48). This has some bugs, when detecting VersionNT & VersionNT64, which have been addressed in the scripts here.