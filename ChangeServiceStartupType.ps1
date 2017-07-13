# Start/stop service on multiple server

# **************************************************************
# *******    catch the argument pass to this script     ********
# **************************************************************

param ( [string]$TargetServer, [string]$TargetServerList, [string]$ServiceName, [string]$ServiceNameList, [string]$StartupType, [string]$bin, [string]$LogMod, [string]$logfile, [string]$debug )

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

if ( ((!$TargetServer) -and (!$TargetServerList)) -or ((!$ServiceName) -and (!$ServiceNameList)) -or (!$StartupType) -or (($TargetServer) -and ($TargetServerList)) -or (($ServiceName) -and ($ServiceNameList)) )
{ 
	$scriptname = $MyInvocation.MyCommand.Name
	write-host "Invalid input detected, to use this script, you need to pass some argument to it." -foregroundcolor red
	write-host ".\$scriptname -TargetServer [Name of the server you want to work on] -ServiceName [Name of the service you want to change its startup type] -StartupType [Start / Stop / restart]" -foregroundcolor red
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

# We only accept Automatic/Manual/Disabled as the startup type to the service
$ValidStartupTypeList = "Automatic","Manual","Disabled"
foreach ($ValidStartupType in $ValidStartupTypeList)
{
	write-debug "This valid action is $ValidAction"
	if ($StartupType -eq $ValidStartupType)
	{
		write-debug "The user specified startup type is valid"
		$StartupTypeValidation = "true"
	}
}
if ($StartupTypeValidation -ne "true")
{
	log -logstring "The user specified startup type is not a valid startup type, existing the script" -app $cmd -logfile $logfile -color red
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
		foreach ($Service in $ServiceNameArr)
		{
			write-debug "The service we are going to work on is $Service"
						
			#$TargetService = get-service -ComputerName $Server -Name $Service -errorvariable err
			$TargetService = get-wmiobject -class Win32_Service -ComputerName $Server | where {$_.Name -eq $Service}
			if (!$TargetService)
			{
				log -logstring "The service $Service does not seems to be exist on $Server, not going to change the startup type to $StartupType" -app $cmd -logfile $logfile -color red
			}
			else
			{
				# Check the service startup type before action
				$ServiceCurrentStartupType = $TargetService.StartMode
				write-debug "The startup type of $Service is $ServiceSCurrentStartupType"
				
				If (($StartupType -eq "Automatic") -and ($ServiceCurrentStartupType -eq "Auto"))
				{
					log -logstring "The startup type of service $Service on $Server is already $StartupType, not going to do anything" -app $cmd -logfile $logfile
				}
				else
				{
					If ($ServiceCurrentStartupType -eq $StartupType)
					{
						log -logstring "The startup type of service $Service on $Server is already $StartupType, not going to do anything" -app $cmd -logfile $logfile
					}
					else
					{
						log -logstring "The startup type of service $Service on $Server is $ServiceCurrentStartupType, changing it to $StartupType" -app $cmd -logfile $logfile
						Set-Service -ComputerName $Server -Name $TargetService.Name -StartupType $StartupType -errorvariable err
						if ($err)
						{
							log -logstring "[Error] Failed to change the startup type of service $Service on $Server to $StartupType" -app $cmd -logfile $logfile
						}
						else
						{
							log -logstring "Successfully changed the startup type of service $Service on $Server to $StartupType" -app $cmd -logfile $logfile
						}
					}				
				}
			}
		}
	}	
}

