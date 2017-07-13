# Start/stop service on multiple server

# **************************************************************
# *******    catch the argument pass to this script     ********
# **************************************************************

param ( [string]$TargetServer, [string]$TargetServerList, [string]$ScheduledTask, [string]$ScheduledTaskList, [string]$TaskStatus, [string]$bin, [string]$LogMod, [string]$logfile, [string]$debug )

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
if ( ((!$TargetServer) -and (!$TargetServerList)) -or ((!$ScheduledTask) -and (!$ScheduledTaskList)) -or (!$TaskStatus) -or (($TargetServer) -and ($TargetServerList)) -or (($ScheduledTask) -and ($ScheduledTaskList)) )
{ 
	$scriptname = $MyInvocation.MyCommand.Name
	write-host "Invalid input detected, to use this script, you need to pass some argument to it." -foregroundcolor red
	write-host ".\$scriptname -TargetServer [Name of the server you want to work on] -ScheduledTask [Name of the Scheduled Task you want to work on] -TaskStatus [Start / Stop / Enable / Disable]" -foregroundcolor red
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

# Put a starting line in the log file to improve readability
log -logstring "************************ $cmd is triggered by $(whoami) ************************ " -app $cmd -logfile $logfile


# *****************************************************
# ****           	   Validation            	   ****
# *****************************************************

# We only accept Enabled/Disabled/Start/Stop as the startup type to the service
$ValidTaskStatusList = "Enabled","Disabled","Start","Stop"
foreach ($ValidTaskStatus in $ValidTaskStatusList)
{
	write-debug "This valid action is $ValidAction"
	if ($TaskStatus -eq $ValidTaskStatus)
	{
		write-debug "The user specified startup type is valid"
		$TaskStatusValidation = "true"
	}
}
if ($TaskStatusValidation -ne "true")
{
	log -logstring "The user specified Task Status ($TaskStatus) is not valid, existing the script" -app $cmd -logfile $logfile -color red
	exit
}

# validate the Server list
if ($TargetServerList)
{
	if ( -not ( Test-Path -Path $TargetServerList )) 
	{ 
		log -logstring "ERROR!!! $TargetServerList does not exist" app $cmd -logfile $logfile -color red
	}
}

# validate the Service list
if ($ScheduledTaskList)
{
	if ( -not ( Test-Path -Path $ScheduledTaskList )) 
	{ 
		log -logstring "ERROR!!! $ScheduledTaskList does not exist" -app $cmd -logfile $logfile -color red
	}
}


# *****************************************************
# ****            Start of the Script              ****
# *****************************************************

#convert the Server list into an array
if ($TargetServer)
{
	$TargetServerArr = $TargetServer -split","
}
if ($TargetServerList)
{
	# init a arry to store the extracted value
	$TargetServerArr = New-Object System.Collections.ArrayList

	foreach ($line in get-content $TargetServerList)
	{
		$TargetServerArr.add($line)
	}
}

#convert the Service Name list into an array
if ($ScheduledTask)
{
	$ScheduledTaskArr = $ScheduledTask -split","
}
if ($ScheduledTaskList)
{
	# init a arry to store the extracted value
	$ScheduledTaskArr = New-Object System.Collections.ArrayList

	foreach ($line in get-content $ScheduledTaskList)
	{
		$ScheduledTaskArr.add($line)
	}
}


foreach ($Server in $TargetServerArr)
{
	write-debug "The server we are working on is $Server"	
	# Check if the target server is up
	$pingcounter = 0
	$ServerStatus = 0
	do {
		Test-Connection -count 1 -Computername $Server -errorvariable err
		if (!$err)
		{
			$ServerStatus++
			$pingcounter = 5
		}
		$pingcounter++
	} while ($pingcounter -lt 5)
	if ($ServerStatus -eq 0)
	{
		log -logstring "The target server $Server does not seems to be up, skipping to the next server" -app $cmd -logfile $logfile -color red
	}
	else
	{		
		foreach ($Task in $ScheduledTaskArr)
		{
			write-debug "The Task we are going to work on is $Task"
						
			($TaskScheduler = New-Object -ComObject Schedule.Service).Connect($Server)
			$MyTask = $TaskScheduler.GetFolder('\').GetTask($Task)
			
			If (!$?)
			{
				log -logstring "Could not find $Task on $Server" -app $cmd -logfile $logfile
			}
			else
			{
				# Enable the task
				If ($TaskStatus -eq 'Enabled')
				{
					log -logstring "Enabling the task $Task on $Server" -app $cmd -logfile $logfile
					$MyTask.Enabled = $true
					if ($?)
					{
						log -logstring "Successfully enabled $Task on $Server" -app $cmd -logfile $logfile
					}
					else 
					{
						log -logstring "Failed to enable $Task on $Server" -app $cmd -logfile $logfile
					}
				}
			
				# Disable the task
				If ($TaskStatus -eq 'Disabled')
				{
					log -logstring "Disabling the task $Task on $Server" -app $cmd -logfile $logfile
					$MyTask.Enabled = $false
					if ($?)
					{
						log -logstring "Successfully disabled $Task on $Server" -app $cmd -logfile $logfile
					}
					else 
					{
						log -logstring "Failed to disable $Task on $Server" -app $cmd -logfile $logfile
					}
				}
			
				# Run the task
				If ($TaskStatus -eq 'Start')
				{
					log -logstring "Running the task $Task on $Server" -app $cmd -logfile $logfile
					schtasks /run /s $Server /tn $Task
					if ($?)
					{
						log -logstring "Successfully started $Task on $Server" -app $cmd -logfile $logfile
					}
					else 
					{
						log -logstring "Failed to start $Task on $Server" -app $cmd -logfile $logfile
					}
				}
			
				# Stop the task
				if ($TaskStatus -eq 'Stop')
				{
					log -logstring "Stopping the task $Task on $Server" -app $cmd -logfile $logfile
					schtasks /end /s $Server /tn $Task
					if ($?)
					{
						log -logstring "Successfully stopped $Task on $Server" -app $cmd -logfile $logfile
					}
					else 
					{
						log -logstring "Failed to stop $Task on $Server" -app $cmd -logfile $logfile
					}
				}			
			}
		}
	}	
}

