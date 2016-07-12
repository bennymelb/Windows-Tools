#PowerShell Logging Script 

 
# logging function
function log()
{
	Param  
    (                 
		[string]$logstring,
		[string]$logfile,
		[string]$color,
		[string]$app
			
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
	
	if (!$color) {$color = "white"}
	write-host $logstring -foregroundcolor $color
	if ($logfile) 
	{
		$CurrentDate = get-date -format M
		$CurrentTime = get-date -Uformat %T
		$logstring =  "$CurrentDate $CurrentTime $env:computername $app : $logstring"
		$logstring | out-file -Filepath $logfile -append
	}	
}

