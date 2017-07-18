# https://msdn.microsoft.com/en-us/library/windows/desktop/aa383607(v=vs.85).aspx

# **********************************
# ****   Written by Benny Lo    ****
# **********************************

# **************************************************************
# *******    catch the argument pass to this script     ********
# **************************************************************

param ( [string]$TaskName, [string]$TaskDescr, [string]$TaskCommand, [string]$TaskArg, [string]$TaskLoc, [string]$TaskStartTime, [string]$TaskRepInterval, [string]$TaskRepDuration, [string]$TaskRunAs, [string]$TaskRunAsPW, [int]$TaskRunLevel, [string]$TargetServer,[string]$bin, [string]$LogMod, [string]$logfile, [string]$debug )


# *****************************************************
# ****             initial env setup               ****
# *****************************************************

# Set the debug switch
if ($debug)
{
	$DebugPreference = $debug
}

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

# Display the script usage if necessary variable is not defined or passed to this script

if ( (!$TaskName) -or (!$TaskCommand) -or (($TaskRunAs) -and (!$TaskRunAsPW)) )
{ 
	$scriptname = $MyInvocation.MyCommand.Name
	write-host "Invalid input detected, to use this script, you need to pass some argument to it." -foregroundcolor red
	write-host ".\$scriptname -TaskName [Name of the Scheduled task] -TaskCommand [The program/script you want to run]" -foregroundcolor red
	exit
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

# Set the target server to localhost if user didn't specify any server
if (!$TargetServer)
{
	$TargetServer ="localhost"
}

# Convert the Server list into an array
if ($TargetServer)
{
	$TargetServerArr = $TargetServer -split","
}


# *****************************************************
# ****           	   Validation            	   ****
# *****************************************************

# Set the start time to 1 minute after we created the task if user didn't specify any start time
if (!$TaskStartTime)
{
	$DefaultTaskStartTime = [datetime]::Now.AddMinutes(1) 
	$TaskStartTime = $DefaultTaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
	write-debug "The Task start time is $TaskStartTime"
}

# *****************************************************
# ****            Start of the Script              ****
# *****************************************************

# Put a starting line in the log file to improve readability
log -logstring "************************ $cmd is triggered by $(whoami) ************************ " -app $cmd -logfile $logfile

 
Foreach ($Server in $TargetServerArr)
{
	write-debug "The server we are working on is $Server"	
	# Check if the target server is up
	Test-Connection -Computername $Server -errorvariable err
	if ($err)
	{
		log -logstring "The target server $Server does not seems to be up, not going to create the schdeuled task $TaskName on $Server" -app $cmd -logfile $logfile -color red
	}
	else
	{		
		log -logstring "Creating the schdeuled task $TaskName on $Server" -app $cmd -logfile $logfile
		
		# attach the Task Scheduler com object
		$service = new-object -ComObject("Schedule.Service")
		# connect to the local machine. 
		# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx
		$service.Connect($Server)
		$rootFolder = $service.GetFolder("\")
 
		$TaskDefinition = $service.NewTask(0) 
		$TaskDefinition.RegistrationInfo.Description = "$TaskDescr"
		$TaskDefinition.Settings.Enabled = $true
		$TaskDefinition.Settings.AllowDemandStart = $true
		If ($TaskRunAs) { $TaskDefinition.RegistrationInfo.Author = $TaskRunAs }
		#$TaskDefinition.Principal.LogonType = "TaskLogonType.Password" 
		If ($TaskRunLevel) { $TaskDefinition.Principal.RunLevel = $TaskRunLevel }
 
		$triggers = $TaskDefinition.Triggers
		#http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
		# Creates a "Daily" trigger
		$trigger = $triggers.Create(2) 
		if ($TaskRepInterval) { $trigger.Repetition.Interval = "PT" + $TaskRepInterval + "M" }
		if ($TaskRepDuration) { $trigger.Repetition.Duration = "PT" + $TaskRepDuration + "M" }
		$trigger.StartBoundary = $TaskStartTime
		$trigger.Enabled = $true
 
		# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
		$Action = $TaskDefinition.Actions.Create(0)
		$Action.Path = "$TaskCommand"
		if ($TaskArg) { $Action.Arguments = "$TaskArg" }
		if ($TaskLoc) { $Action.WorkingDirectory = "$TaskLoc"}
 
		#http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
		If (!$TaskRunAS)
		{
			$rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5)
		}
		else
		{
			$rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,$TaskRunAs,$TaskRunAsPW,1)	
		}
	}
}
