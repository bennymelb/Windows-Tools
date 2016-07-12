# **********************************
# ****   Written by Benny Lo    ****
# ****        05-03-2016        ****
# ****       Version 1.0        ****
# **********************************

# **************************************************************
# *******    catch the argument pass to this script     ********
# **************************************************************

param ( [string]$srcpath , [string]$dstpath, [int]$howmanyfiletomove, [string]$bin, [string]$LogMod, [string]$logfile, [string]$debug )

if ($debug)
{
	$DebugPreference = $debug
}

write-debug "Source path pass to this script is $srcpath"
write-debug "Destination path pass to this script is $dstpath"
write-debug "Number of file to move pass to this script is $howmanyfiletomove"
write-debug "Bin location is $bin"
write-debug "Logging function script is $LogMod"
write-debug "Log File is $logfile"


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

# If user didn't specify a bin location, we assume other tool is in the same folder as the current script 
if (!$bin) 
{
	$bin = Split-Path $MyInvocation.MyCommand.Path
}
# if user didn't specoify the logging function script, we use the default script
if (!$LogMod) 
{ 
	$LogMod = "Logging.PS1" 
}

# Test if path is relative or absolute
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

# check if logging function script exist
if ( -not ( Test-Path -Path $LogMod )) 
{ 
	write-host "ERROR!!! $LogMod does not exist" -foregroundcolor red
}
else
{
	# load the logging function
	. $LogMod
}

# If User didn't specify how many file to move, we will set this to -1 which means move all
if (!$howmanyfiletomove) 
{	
	$howmanyfiletomove = -1 
}


if (!$srcpath -or !$dstpath) 
{
	write-host "invalid input detected, not going to move the file !!!!!!!!!!" -foregroundcolor red
	exit
}

# *****************************************************
# ****              Path validation                ****
# *****************************************************


## Validate sourc path & destination path
if ( -not (Test-Path $srcpath -PathType Container ))  
{ 
	log -logstring "Error!!! $srcpath is not a valid path" -color red -app $cmd -logfile $logfile 
	exit
}

if (-not (Test-Path $dstpath -PathType Container )) 
{
	log -logstring "Error!!! $dstpath is not a valid path" -color red -app $cmd -logfile $logfile
	exit
}

# check if source & destination folder is same
if ( $srcpath -eq $dstpath) 
{
	log -logstring "Error!!! Source and Destination folder is the same, not moving any file" -color red -app $cmd -logfile $logfile
	exit
}


# *****************************************************
# ****            Start of the Script              ****
# *****************************************************

# Check if any file exist in $srcpath, if so, how many, record this in the log for audit

log -logstring "Scanning $srcpath ......" -app $cmd -logfile $logfile 

$directoryInfo = gci -File $srcpath | Measure-Object
$FileCount = $directoryInfo.count 

if ($FileCount -eq 0)
{
	log -logstring "$srcpath does not contain any file" -app $cmd -logfile $logfile
	exit
}
else
{
	log -logstring "$srcpath contain $FileCount file(s)" -app $cmd -logfile $logfile
}

if ($howmanyfiletomove -ge 1)
{
	log -logstring "Number of file to move is set to $howmanyfiletomove" -app $cmd -logfile $logfile
}
else
{
	log -logstring "Number of file to move is not specified, going to move all file(s)" -app $cmd -logfile $logfile
}

$counter = 0

foreach ($file in gci -File $srcpath) 
{
	log -logstring "moving $file from $srcpath to $dstpath" -app $cmd -logfile $logfile
	move-item -literalPath $file.FullName -destination $dstpath -ErrorVariable err
		
	if (!$err)
	{
		# The move operation is successful, verify the the file is copied over to the destination folder			
		if ( -not ( Test-Path -literalPath $dstpath\$file )) 
		{ 
			log -logstring "Error!!! Failed to move $file to $dstpath"	-color red -app $cmd -logfile $logfile
		}
		else 
		{
			log -logstring "successfully moved $file to $dstpath" -app $cmd -logfile $logfile								
		}
		
	}
	else
	{
		# The copy operation is failed
		log -logstring "Error!!! Failed to move $file to $dstpath" -color red -app $cmd -logfile $logfile
		log -logstring $err -color red -app $cmd -logfile $logfile
	}
	
	
	
	$counter = $counter + 1
	if ($counter -eq $howmanyfiletomove) 
	{ 
		log -logstring "Reach the user specified number of file to move" -app $cmd -logfile $logfile
		break 
	}
}