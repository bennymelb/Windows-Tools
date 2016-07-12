# Start/stop service on multiple server

# **********************************
# ****   Written by Benny Lo    ****
# ****        20-03-2016        ****
# ****       Version 1.0        ****
# **********************************

# **************************************************************
# *******    catch the argument pass to this script     ********
# **************************************************************

param ( [string]$TargetServer, [string]$TargetServerList, [string]$ServiceName, [string]$ServiceNameList, [string]$Action, [string]$bin, [string]$LogMod, [string]$logfile, [string]$debug )

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

if ( ((!$TargetServer) -and (!$TargetServerList)) -or ((!$ServiceName) -and (!$ServiceNameList)) -or (!$Action) -or (($TargetServer) -and ($TargetServerList)) -or (($ServiceName) -and ($ServiceNameList)) )
{ 
	$scriptname = $MyInvocation.MyCommand.Name
	write-host "Invalid input detected, to use this script, you need to pass some argument to it." -foregroundcolor red
	write-host ".\$scriptname -TargetServer [Name of the server you want to start the service] -ServiceName [Name of the service you want to start or stop] -Action [Start / Stop / restart]" -foregroundcolor red
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

# We only accept Start/stop/query as the action to the service
$ValidActionList = "Start","Stop","Restart"
foreach ($ValidAction in $ValidActionList)
{
	write-debug "This valid action is $ValidAction"
	if ($Action -eq $ValidAction)
	{
		write-debug "The user specified action is a valid action"
		$ActionValidation = "true"
	}
}
if ($ActionValidation -ne "true")
{
	log -logstring "The user specified action is not a valid action, existing the script" -app $cmd -logfile $logfile -color red
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
if ($ServiceNameList)
{
	if ( -not ( Test-Path -Path $ServiceNameList )) 
	{ 
		log -logstring "ERROR!!! $ServiceNameList does not exist" -app $cmd -logfile $logfile -color red
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
if ($ServiceName)
{
	$ServiceNameArr = $ServiceName -split","
}
if ($ServiceNameList)
{
	# init a arry to store the extracted value
	$ServiceNameArr = New-Object System.Collections.ArrayList

	foreach ($line in get-content $ServiceNameList)
	{
		$ServiceNameArr.add($line)
	}
}


foreach ($Server in $TargetServerArr)
{
	write-debug "The server we are working on is $Server"	
	# Check if the target server is up
	Test-Connection -Computername $Server -errorvariable err
	if ($err)
	{
		log -logstring "The target server $Server does not seems to be up, not going to $Action any service for $Server" -app $cmd -logfile $logfile -color red
	}
	else
	{		
		foreach ($Service in $ServiceNameArr)
		{
			write-debug "The service we are going to work on is $Service"
						
			$TargetService = get-service -ComputerName $Server -Name $Service -errorvariable err
			if ($err)
			{
				log -logstring "The service $Service does not seems to be exist on $Server, not going to $Action $Service on $Server" -app $cmd -logfile $logfile -color red
			}
			else
			{
				# Check the service status before action
				$ServiceStatus = $TargetService.Status
				write-debug "The status of $Service is $ServiceStatus"
								
				if ($Action -eq	'Start')
				{					
					If ($ServiceStatus -eq 'Running')
					{
						log -logstring "The service $Service on $Server is already $ServiceStatus, not going to $Action the service" -app $cmd -logfile $logfile
					}
					else
					{
						Start-Service -InputObject $TargetService -Verbose -errorvariable err			
						if ($err)
						{
							log -logstring "Failed to start the service $Service on $Server" -app $cmd -logfile $logfile -color red
							log -logstring "$err" -app $cmd -logfile $logfile -color red
						}
						else
						{
							log -logstring "Successfully started the service $Service on $Server" -app $cmd -logfile $logfile
						}
					}
				}	
				if ($Action -eq 'Stop')
				{
					If ($ServiceStatus -eq 'Stopped')
					{
						log -logstring "The service $Service on $Server is already $ServiceStatus, not going to $Action the service" -app $cmd -logfile $logfile
					}
					else
					{
						Stop-Service -InputObject $TargetService -force -Verbose -errorvariable err
						if ($err)
						{
							log -logstring "Failed to stop the service $Service on $Server" -app $cmd -logfile $logfile -color red
							log -logstring "$err" -app $cmd -logfile $logfile -color red
						}
						else
						{
							log -logstring "Successfully stopped the service $Service on $Server" -app $cmd -logfile $logfile
						}
					}
				}
				if ($Action -eq 'Restart')
				{
					Restart-Service -InputObject $TargetService -force -Verbose -errorvariable err
					if ($err)
					{
						log -logstring "Failed to restart the service $Service on $Server" -app $cmd -logfile $logfile -color red
						log -logstring "$err" -app $cmd -logfile $logfile -color red
					}
					else
					{
						log -logstring "Successfully restarted the service $Service on $Server" -app $cmd -logfile $logfile 
					}
				}				
			}
		}
	}	
}

