#PowerShell Logging Script 

 
# logging function
function log()
{
	Param  
    (                 
		[string]$logstring,
		[string]$logfile,
		[string]$color,
		[string]$app,
		[string]$SessionID
    )   
	
	if (!$logstring) 
	{ 
		write-host "Error!!! no log is passed to the logging function" -foregroundcolor red
		return
	}
	
	if (!$app)
	{
		$app = "UnknownApp"
	}
	
	if (!$SessionID)
	{
		$SessionID = "n/a"
	}
	
	if (!$color) {$color = "white"}
	write-host $logstring -foregroundcolor $color
	if ($logfile) 
	{
		$CurrentDateTime = get-date -format "MMM dd yyyy HH:mm:ss"		
		$logstring =  "$CurrentDateTime $env:computername $app [" + $sessionID + "] [INFO] : $logstring"
		$logstring | out-file -Filepath $logfile -append -encoding ASCII
	}	
}

function log-error()
{
	Param  
    (                 
		[string]$logstring,
		[string]$logfile,
		[string]$color,
		[string]$app,
		[string]$SessionID				
    )   
	
	
	if (!$logstring) 
	{ 
		write-host "Error!!! no log is passed to the logging function" -foregroundcolor red
		return
	}
	
	if (!$app)
	{
		$app = "UnknownApp"
	}
		
	if (!$SessionID)
	{
		$SessionID = "n/a"
	}
	
	if (!$color) {$color = "Red"}
	write-host $logstring -foregroundcolor $color
	if ($logfile) 
	{
		$CurrentDateTime = get-date -format "MMM dd yyyy HH:mm:ss"
		$logstring =  "$CurrentDateTime $env:computername $app [" + $sessionID + "] [ERROR] : $logstring"
		$logstring | out-file -Filepath $logfile -append -encoding ASCII
		
	}
}

function log-debug()
{
	Param  
    (                 
		[string]$logstring,
		[string]$logfile,
		[string]$color,
		[string]$app,
		[string]$SessionID,
		[string]$debug			
    )   
	
	if (($debug) -and ($debug -ne "SilentlyContinue"))
	{
		if (!$logstring) 
		{ 
			write-host "Error!!! no log is passed to the logging function" -foregroundcolor red
			return
		}
	
		if (!$app)
		{
			$app = "UnknownApp"
		}
		
		if (!$SessionID)
		{
			$SessionID = "n/a"
		}
	
		if (!$color) {$color = "Yellow"}
		write-host $logstring -foregroundcolor $color
		if ($logfile) 
		{
			$CurrentDateTime = get-date -format "MMM dd yyyy HH:mm:ss"
			$logstring =  "$CurrentDateTime $env:computername $app [" + $sessionID + "] [DEBUG] : $logstring"
			$logstring | out-file -Filepath $logfile -append -encoding ASCII
		}	
	}
}
