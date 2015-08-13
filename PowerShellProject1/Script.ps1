# Martino Jones
# 20150203
# This script is for updating WIMs
# NEED DISM
# v1.0

$ErrorActionPreference = "SilentlyContinue"
#This will make sure DISM is installed

#Ask for the version of Windows
[float]$windowsVersion = Read-Host -Prompt "What version of Windows are you trying to update?"

switch ($windowsVersion)
{
	8.1 {$windowsVersion = 8.1}
	10 {$windowsVersion = 10}
	default {$windowsVersion = 8.1}
}



$dismPath = "C:\Program Files (x86)\Windows Kits\$windowsVersion\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"
$dismPath
$testDISMPath = test-path $dismPath
$findDISMPathLoop = 0
do{
if($testDISMPath -eq $false)
{
	Write-Host -ForegroundColor Red "Warning, DISM wasn't found, we need that"
	Write-Host -ForegroundColor Red "I tested $testDISMPath"
	$dismPath = Read-Host -Prompt "Please provide the path to DISM, or install DISM with ADK"
}
	else 
	{
		$findDISMPathLoop = 1
	}
	} until ($findDISMPathLoop -eq 1)

#Import DISM module
Write-Host "Please wait, importing DISM module..."
import-module $dismPath -WarningAction SilentlyContinue

#Functions
#Function for counting down before rebooting
function CountDown() {
    param(
    [int]$seconds=0,
    [int]$minutes=0,
    [int]$hours=0
    )
 
    if ($help -or (!$hours -and !$minutes -and !$seconds)){
        write-host $HelpInfo
        return
        }
    $startTime = get-date
    $endTime = $startTime.addHours($hours)
    $endTime = $endTime.addMinutes($minutes)
    $endTime = $endTime.addSeconds($seconds)
    $timeSpan = new-timespan $startTime $endTime
    write-host $([string]::format("`nScript paused for {0:#0}:{1:00}:{2:00}",$hours,$minutes,$seconds)) -backgroundcolor black -foregroundcolor yellow
    while ($timeSpan -gt 0) {
        $timeSpan = new-timespan $(get-date) $endTime
        write-host "`r".padright(40," ") -nonewline
        write-host "`r" -nonewline
        write-host $([string]::Format("`rTime Remaining: {0:d2}:{1:d2}:{2:d2}", `
        $timeSpan.hours, `
        $timeSpan.minutes, `
        $timeSpan.seconds)) `
        -backgroundcolor black -foregroundcolor yellow
        sleep 1
        }
    write-host ""
    }

write-host "Looking for Windows.wim file"
$wimPath = "windows.wim"
$findWimLoop = 0

#This is for cleaning up corrupted mounts, Windows does this from time to time
Write-Host "Cleaning up corrupt mounts"
Clear-WindowsCorruptMountPoint


do {
$wimFound = Test-Path $wimPath

#If windows.wim wasn't found then prompt error and ask for location
if($wimFound -eq $false)
{
	Write-Host -ForegroundColor Red "The $wimPath file wasn't found!"
	$wimPath = Read-Host -Prompt "Please specify the path for the WIM"
}
	else
	{
		$findWimLoop = 1
	}

} until ($findWimLoop -eq 1)

Write-Host "Found WIM: $wimPath"

#Specify path and mount WIM
$mountPath = "C:\mount"
$findmountLoop = 0
do{
$testDefaultMount = Test-Path $mountPath
if($testDefaultMount -eq $false){
$mountPath = Read-Host -Prompt "Please specify the path to mount your WIM"
$testMountPath = Test-Path $mountPath
if ($testMountPath -eq $false)
{
	Write-Host "The path wasn't found, we need that path to exist to mount."
	$askMountPathMake = Read-Host -Prompt "Would you like me to make that path?"
	if ($askMountPathMake -like "*y*")
	{
		try
		{
			New-Item -Path $mountPath -ItemType Directory
		}
		catch [system.exception]
		{
			Write-Host "There was an error making the path you specified"
			Write-Host $Error
		}
	}
}
	}
	else
	{
		$testMountedMatch = (Get-WindowsImage -mounted | where {$_.Path -eq $mountPath}).count
		if($testMountedMatch -gt 0)
		{
			Write-Host "There was a mount found at this point, we need to unmount this!"
			Dismount-WindowsImage -Discard -Path $mountPath
			Clear-WindowsCorruptMountPoint

		}
		else
		{
			$findmountLoop = 1
		}
		
	}
	} until ($findmountLoop -eq 1)


#Get Index number
[int]$wimIndex
$numberOfIndex = Get-WindowsImage -imagepath $wimPath | select-Object ImageIndex
$numberOfIndex = $numberOfIndex.imageindex
if($numberOfIndex -gt 1)
{
	$wimIndex = Read-Host "Please provide the Index of the WIM"
}
else
{
	$wimIndex = 1
}

#Test and mount the WIM
#This will mak sure the path specified is empty
$directoryInfo = gci C:\mount | Measure-Object
if($directoryInfo.Count -gt 0)
{
	Write-Host "There are files in this folder, this will cause issues, we need to clean it up"
	Remove-Item $mountPath -Recurse
	New-Item -Path $mountPath -ItemType Directory
}

try 
{
	Mount-WindowsImage -ImagePath $wimPath -Index $wimIndex -Path $mountPath
}
catch [system.exception]
{
	Write-Host -ForegroundColor Red "There was an error mounting the WIM"
	Write-Host -ForegroundColor Red $Error
}


#Get Updates Folder
$updatesFolder = "updates"
$findUpdatesLoop = 0
do{
$testUpdatesFolder = Test-Path $updatesFolder
if($testUpdatesFolder -eq $false)
{
	Write-Host "No updates folder path found"
	$updatesFolder = Read-Host -Prompt "Please specify the folder with your updates to inject"

}
	else
	{
		$findUpdatesLoop = 1
	}
	} until ($findUpdatesLoop -eq 1)


#Apply updates
try
{
	Add-WindowsPackage -PackagePath $updatesFolder -Path $mountPath
}
catch [system.exception]
{
	Write-Host -ForegroundColor Red "There was an error adding updates"
	Write-Host -ForegroundColor Red $Error
}

#Get Drivers Folder
$driversFolder = "drivers"
$findDriversLoop = 0

do{
$testDriversFolder = Test-Path $driversFolder
if ($testDriversFolder -eq $false)
{
	Write-Host "Didn't find a drivers folder."
	$driversFolder = Read-Host "Please specify the folder where your drivers are located"

}
	else
	{
		$findDriversLoop = 1
	}
	} until ($findDriversLoop -eq 1)


#inject drivers
try
{
	Write-Host "Injecting Drivers from $driversFolder to $mountPath"
	Add-WindowsDriver -Recurse -Path $mountPath -Driver $driversFolder
}
catch [system.exception]
{
	Write-Host -ForegroundColor Red "There was an error adding the drivers"
	Write-Host -ForegroundColor Red $Error
}

#Find unattend file
$askUnattendFile = Read-Host "Would you like to inject unattend file?"
if ($askUnattendFile -like "*y*")
{
	$unattendFile = "unattend.xml"
	$testUnattendLoop = 0
	do{
	$testUnattendFile = Test-Path $unattendFile
	if($testUnattendFile -eq $false)
	{
		Write-Host "Was unable to find the unattend.xml file."
		$unattendFile = Read-Host -Prompt "Please provide the unattend file path:"
	} 
	else
	{
		$testUnattendLoop = 1
	}
		} until ($testUnattendLoop -eq 1)


}

#Inject unattend if provided
if($askUnattendFile -like "*y*")
{

	try
	{
		Use-WindowsUnattend -Path $mountPath -UnattendPath $unattendFile
	}
	catch [system.exception]
	{
	Write-Host -ForegroundColor Red "There was an error adding the unattend file"
	Write-Host -ForegroundColor Red $Error
	}
}

#Check if Netfx3 is enabled
$netFX3 = get-Windowsoptionalfeature -path $mountPath | where {$_.FeatureName -eq "NetFx3"}
if($netFX3.State -ne "enabled")
{
	$askEnableNetFX3 = Read-Host -Prompt "NetFX3 isn't enabled, would you like to enable it?"
	if($askEnableNetFX3 -like "*y*")
	{
		Enable-WindowsOptionalFeature -FeatureName NetFx3 -Path $mountPath
	}
	else
	{
		Write-Host "Found fxnet3 on system, skipping step."
	}
}

#ask to unmount and commit
Write-Host "All done!"
$askToUnmount = Read-Host "Would you like to unmount and commit?"
if($askToUnmount -like "*y*")
{
	Dismount-WindowsImage -Save -Path $mountPath

	#Cleanup corrupted mountpoint if Windows doesn't dismount properly, happens a lot
	Write-Host "Cleanup..."
	Clear-WindowsCorruptMountPoint
	CountDown(10)

}
else
{
	Dismount-WindowsImage -Discard -Path $mountPath
	Write-Host "Exiting, you will need to unmount the WIM when you're done."

	#Cleanup corrupted mountpoint if Windows doesn't dismount properly, happens a lot
	Write-Host "Cleanup..."
	Clear-WindowsCorruptMountPoint
	CountDown(10)
	
}