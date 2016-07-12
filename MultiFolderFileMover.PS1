# **********************************
# ****   Written by Benny Lo    ****
# ****        03-03-2016        ****
# ****       Version 1.0        ****
# **********************************

# **************************************************************
# *******    catch the argument pass to this script     ********
# **************************************************************

param ( 

# This is the folder that contain the All FTP party's root folder e.g. E:\Intouch\Connectors\FTPUsers
[string]$srcparentfolder,

# This is the source folder under each FTP party's folder where you are trying to move file from e.g. inbox
[string]$srcfolder,

# This is the destination folder under each FTP party's folder where you are trying to move file to e.g. inbox\processed
[string]$dstfolder,

# This is the destination parent folder under each FTP party's folder where you are trying to move file to e.g. inbox\processed
[string]$dstparentfolder,

# This is the number of file to move at a time, set this to -1 means move all file
[int]$howmanyfiletomove,

# (Optional) bin location where other tools is located
[string]$bin,

# (optional) Filemover script
[string]$Filemover,

# (optional) Logging function script
[string]$LogMod, 

# User specified logfile (full path)
[string]$logfile, 

# debug switch
[string]$debug

)

# Set the debug switch
if ($debug)
{
	$DebugPreference = $debug
}

write-debug "logfile is $logfile"


# *****************************************************
# ****             initial env setup               ****
# *****************************************************

# Get current Script name
$cmd = $MyInvocation.ScriptName
if ($cmd)
{
	# Set the name to the calling script name if this script is called from another script / function
	$cmd = $MyInvocation.ScriptName.Replace((Split-Path $MyInvocation.ScriptName),'').TrimStart('\')
}
else
{
	# Set the name to this script if its not called from another script / function
	$cmd = $MyInvocation.MyCommand.Name
}

write-debug "cmd is $cmd"

# Display the script usage if necessary variable is not defined or passed to this script

if ((!$srcparentfolder) -or ($srcparentfolder -and !$srcfolder -and !$dstfolder -and !$dstparentfolder)) 
{ 
	$scriptname = $MyInvocation.MyCommand.Name
	write-host "Invalid input detected, to use this script, you need to pass some argument to it." -foregroundcolor red
	write-host ".\$scriptname -srcparentfolder [Path to the root folder] -srcfolder [Folder to move file from] -dstfolder [Folder to move file to] -howmanyfiletomove [Number of file to move]" -foregroundcolor red
	exit
}

# If user didn't specify a bin location, we assume other tool is in the same folder as the current script 
if (!$bin) 
{
	$bin = Split-Path $MyInvocation.MyCommand.Path
}

# If user didn't specify a filemover script, we use the default script 
if (!$FileMover) 
{
	$FileMover = "FileMover.PS1"
}

# If user didn't specify a logging function script, we use the default script
if (!$LogMod) 
{ 
	$LogMod = "Logging.PS1" 
}

# Test if filemover script is relative or absolute
if ([System.IO.Path]::IsPathRooted($FileMover))
{
	write-debug "$FileMover is a absolute path"
}
else
{
	write-debug "$FileMover is a relative path, making it a absolute path"
	$FileMover = (Join-Path $bin $FileMover)
	write-debug "FileMover script full path is $FileMover" 
}

# Test if logging function script is relative or absolute
if ([System.IO.Path]::IsPathRooted($LogMod))
{
	write-debug "$LogMod is a absolute path"
}
else
{
	write-debug "$LogMod is a relative path, making it a absolute path"
	$LogMod = (Join-Path $bin $LogMod)
	write-debug "Logging function full path is $LogMod" 
}

# check if the filemover script exist
if ( -not ( Test-Path -Path $FileMover )) 
{ 
	write-host "Error!!! $FileMover does not exist" -foregroundcolor red
	exit
}

# check if logging function script exist
if ( -not ( Test-Path -Path $LogMod )) 
{ 
	write-host "Error!!! $LogMod does not exist" -foregroundcolor red
}
else
{
	# load the logging function
	. $LogMod
}
	
# If User didn't specify how many file to move, we will set this to -1 which means move all
if (!$howmanyfiletomove) {	$howmanyfiletomove = -1 }

# Put a starting line in the log file to improve readability
log -logstring "************************ $cmd is triggered by $(whoami) ************************ " -app $cmd -logfile $logfile


# *****************************************************
# ****              Path validation                ****
# *****************************************************

# Check if srcparentfolder is a valid path, exit script if not
if ( -not (Test-Path $srcparentfolder -PathType Container )) 
{ 
	log -logstring "Error!!! $srcparentfolder is not a valid path, exiting the script......" -foregroundcolor red -app $cmd -logfile $logfile
	exit
}

# Check if source folder is a relative path, exit script if not
if ($srcfolder)
{
	if ([System.IO.Path]::IsPathRooted($srcfolder))
	{
		log -logstring "Error!!! Source folder $srcfolder is not a relative path, this is going to break the script, exiting the script......" -foregroundcolor red -app $cmd -logfile $logfile
		exit	
	}
}
	
# Check if destination folder is a relative path, exit script if not
if ($dstfolder)
{	
	if ([System.IO.Path]::IsPathRooted($dstfolder))
	{
		log -logstring "Error!!! Destination folder $dstfolder is not a relative path , this is going to break the script, exiting the script......" -foregroundcolor red -app $cmd -logfile $logfile
		exit
	}
}
	
# check if source & destination folder is same
if (($srcfolder -eq $dstfolder) -and (!$dstparentfolder)) 
{
	log -logstring "Error!!! Source and Destination folder is the same, not moving any file, existing the script....." -foregroundcolor red -app $cmd -logfile $logfile
	exit
}

# Validate destination parent folder only if user has used this option
if ($dstparentfolder) 
{
	# check if destination parent folder is a absolute path, exit script if its not
	if (-not ([System.IO.Path]::IsPathRooted($FileMover)))
	{
		log -logstring "Error!!! $dstparentfolder is not a absolute path, exiting the script......" -foregroundcolor red -app $cmd -logfile $logfile
		exit
	}

	# check if destination parent folder is a valid path, exit script if not
	if ( -not (Test-Path $dstparentfolder -PathType Container )) 
	{ 
		log -logstring "Error!!! $dstparentfolder is not a valid path, exiting the script......" -foregroundcolor red -app $cmd -logfile $logfile
		exit
	}
}


# *****************************************************
# ****            Start of the Script              ****
# *****************************************************

if (!$dstparentfolder)
{
	write-debug "The option Destination Parent folder is not set, this means the destination folder $dstfolder is inside the the source parent folder"
	foreach ($childfolder in gci -directory $srcparentfolder) 
	{
		$childfolderfullpath = $childfolder.FullName
		log -logstring "working on child folder $childfolder in $srcparentfolder" -app $cmd -logfile $logfile
		if (!$srcfolder) 
		{
			log -logstring "going to move file(s) in $childfolderfullpath to $childfolderfullpath\$dstfolder" -app $cmd -logfile $logfile
			. $FileMover -srcpath $childfolderfullpath -dstpath $childfolderfullpath\$dstfolder -howmanyfiletomove $howmanyfiletomove -logfile $logfile
		}
		else 
		{
			if (!$dstfolder) 
			{
				log -logstring "going to move file(s) in $childfolderfullpath\$srcfolder to $childfolderfullpath" -app $cmd -logfile $logfile
				. $FileMover -srcpath $childfolderfullpath\$srcfolder -dstpath $childfolderfullpath -howmanyfiletomove $howmanyfiletomove -logfile $logfile
			}
			else 
			{
				log -logstring "going to move file(s) in $childfolderfullpath\$srcfolder to $childfolderfullpath\$dstfolder" -app $cmd -logfile $logfile
				. $FileMover -srcpath $childfolderfullpath\$srcfolder -dstpath $childfolderfullpath\$dstfolder -howmanyfiletomove $howmanyfiletomove -logfile $logfile
			}
		}
	}
}
# If user do specify a destination parent folder, we will assume it contain the same amount of child folder as the source parent folder. We will then move file from the source folder to the destination folder for every child folder
else
{
	write-debug "User does specify a destination parent folder $dstfolder"
	foreach ($childfolder in gci -directory $srcparentfolder) 
	{
		$childfolderfullpath = $childfolder.FullName
		log -logstring "working on child folder $childfolder in $srcparentfolder" -app $cmd -logfile $logfile
		if (!$srcfolder) 
		{
			log -logstring "going to move file(s) in $childfolderfullpath to $dstparentfolder\$childfolder\$dstfolder" -app $cmd -logfile $logfile
			. $FileMover -srcpath $childfolderfullpath -dstpath $dstparentfolder\$childfolder\$dstfolder -howmanyfiletomove $howmanyfiletomove -logfile $logfile
		}
		else 
		{
			if (!$dstfolder) 
			{
				log -logstring "going to move file(s) in $childfolderfullpath\$srcfolder to $dstparentfolder\$childfolder" -app $cmd -logfile $logfile
				. $FileMover -srcpath $childfolderfullpath\$srcfolder -dstpath $dstparentfolder\$childfolder -howmanyfiletomove $howmanyfiletomove -logfile $logfile
			}
			else 
			{
				log -logstring "going to move file(s) in $childfolderfullpath\$srcfolder to $dstparentfolder\$childfolder\$dstfolder" -app $cmd -logfile $logfile
				. $FileMover -srcpath $childfolderfullpath\$srcfolder -dstpath $dstparentfolder\$childfolder\$dstfolder -howmanyfiletomove $howmanyfiletomove -logfile $logfile
			}
		}
	}
}





