# Martino Jones
# 20150203
# This script is for updating WIMs
# NEED DISM
# v1.0

$ErrorActionPreference = "SilentlyContinue"
#This will make sure DISM is installed
$dismPath = "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"
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
$netFX3 = get-Windowsoptionalfeature -path C:\mount | where {$_.FeatureName -eq "NetFx3"}
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
# SIG # Begin signature block
# MIII9AYJKoZIhvcNAQcCoIII5TCCCOECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9UQIU7VMoawbVShyOSQPoZYH
# MVigggZgMIIGXDCCBUSgAwIBAgIKaxtxPAADAAAaozANBgkqhkiG9w0BAQUFADBP
# MRMwEQYKCZImiZPyLGQBGRYDb3JnMRYwFAYKCZImiZPyLGQBGRYGd2NjbmV0MRIw
# EAYKCZImiZPyLGQBGRYCaXMxDDAKBgNVBAMTA2NhMTAeFw0xNTA3MzExOTM3MTla
# Fw0xNzA3MzAxOTM3MTlaMHcxEzARBgoJkiaJk/IsZAEZFgNvcmcxFjAUBgoJkiaJ
# k/IsZAEZFgZ3Y2NuZXQxEjAQBgoJkiaJk/IsZAEZFgJpczEMMAoGA1UECxMDV0ND
# MQ4wDAYDVQQLEwVTdGFmZjEWMBQGA1UEAxMNTWFydGlubyBKb25lczCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBANSGbG1+yf+n1XjH7i1a4bSlxjoFqECL
# ZH4DKObonu2vShRlt/NADYih+2JcZSsRLd4uLMOZ7Eggur65NUX9Ug+rjEiqZdT6
# GXMDlHKkReRiehJTiEw/9X+8DI8L2arn7Kn0E5zcJpNrzsFhz7GReWk7gldSx3Dm
# ASAT/CAC2xLacdk1f1Zxb8Vs2G52I/Fi6Zy6bLAoVN/EtojWiX6BR78G17Sd/sRh
# euEU4mJTtoMN8cqkHxLFYxzjPzAxfz1TWsJ1U4o4TWXJikh+1D8YQvTsSCitHjsw
# 9fqIH5axMsH6CZtuhJ8x0+RFm/fpKoyLyQzLQpxL6e60FZCS357yyOcCAwEAAaOC
# AxAwggMMMD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCIGPmnGDnJxOhaGTDIGq
# 0TOFrLpZgTiDzY1jyfhcAgFkAgEEMBMGA1UdJQQMMAoGCCsGAQUFBwMDMAsGA1Ud
# DwQEAwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBT4
# pq7BwAkeRChuAoi13gQ2+CXnxTAfBgNVHSMEGDAWgBQGtC2i8E+WiFwfOzrza046
# 6wXYMjCB9wYDVR0fBIHvMIHsMIHpoIHmoIHjhoGvbGRhcDovLy9DTj1jYTEoMyks
# Q049dGV2byxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2Vy
# dmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1pcyxEQz13Y2NuZXQsREM9b3JnP2Nl
# cnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0
# cmlidXRpb25Qb2ludIYvaHR0cDovL3Rldm8uaXMud2NjbmV0Lm9yZy9DZXJ0RW5y
# b2xsL2NhMSgzKS5jcmwwggEKBggrBgEFBQcBAQSB/TCB+jCBpwYIKwYBBQUHMAKG
# gZpsZGFwOi8vL0NOPWNhMSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vydmlj
# ZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1pcyxEQz13Y2NuZXQs
# REM9b3JnP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0
# aW9uQXV0aG9yaXR5ME4GCCsGAQUFBzAChkJodHRwOi8vdGV2by5pcy53Y2NuZXQu
# b3JnL0NlcnRFbnJvbGwvdGV2by5pcy53Y2NuZXQub3JnX2NhMSgzKS5jcnQwRAYD
# VR0RBD0wO6AlBgorBgEEAYI3FAIDoBcMFW1ham9uZXNAaXMud2NjbmV0Lm9yZ4ES
# bWFqb25lc0B3Y2NuZXQuZWR1MA0GCSqGSIb3DQEBBQUAA4IBAQBkIozoFsueFYXj
# opv2hI7isngQyA1/v0gTQmWeyfG70G8N2wUuHGKe9ojPcU1au/Si0HdWE3ufriG8
# A82lt9jtbNNjl/gvZXnGmzgG6nJFgEMmiVAuLsngjCD+BFrNfxbAKyyU15ivTqox
# qdI8BVEQngC9nA1ssrSUGAcFXd5RxIvcALGOjrMH1SST9n5WNcDqGBGmi3YFZUuC
# XDG2YSVw6S6el4GuZSnBqyMJazQCRrlxBU9tfMlcYzPN6VUQh/giIe2LYM7J4sQr
# R7DVlgp8XtTG6uAuSdlzgyN3LHRAAoTA6Dbf1yzqSYdb0JBo/qNksp77MxpyZamG
# kmXc6p0ZMYIB/jCCAfoCAQEwXTBPMRMwEQYKCZImiZPyLGQBGRYDb3JnMRYwFAYK
# CZImiZPyLGQBGRYGd2NjbmV0MRIwEAYKCZImiZPyLGQBGRYCaXMxDDAKBgNVBAMT
# A2NhMQIKaxtxPAADAAAaozAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUv6Pbj0qYt7Ipe028CRyI
# XFmymN0wDQYJKoZIhvcNAQEBBQAEggEAwFEaWLrLQNcO/Kngpd8ilIzf8LAKssal
# c7KtJdYGMtijk3RhlGj1PYeQFIygJeNXzrqA0WwaQ0zSCJdxoOs2w0Z3t/mD5G+U
# L0dbGwowEa1zMahkkgwP/ZJupuewpNm6/NvdVpLJ9G6wAr/tlMrCkaJLNr1PU7se
# wZ1jfiRDqRARga1E5myfTQsLgc74s/ueojsXAuLiTngPKoWvES6C5ssC1xoW9vr9
# jBjbLJm2LmNWs3CzAna7LXYcFs6ckXx09/fkSSC2Uve6tqWD5MsEwefPc/Ekj32E
# nltPOpjYJTjzoPJabRIOGSRU/Kr2cg403Tkl8tqXiEsFDsszhMi2AQ==
# SIG # End signature block
