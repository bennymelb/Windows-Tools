# https://blogs.technet.microsoft.com/heyscriptingguy/2013/01/24/use-powershell-to-change-ip-behavior-with-skipassource/
# written by Benny Lo using the above link for reference

# **************************************************************
# *******    catch the argument pass to this script     ********
# **************************************************************

param ( [string]$netInterface, [string]$primaryIP, [string]$primarySNM, [string]$ReAddPrimaryIP, [string]$SessionID, [string]$bin, [string]$LogMod, [string]$logfile, [string]$debug )


# **************************************************************
# ** Manually set the parameter if running the script directly *
# **************************************************************

# Name of the interface you wanted to work on
#$netInterface = "{netInterface}"


# The primary IP address & subnet mask on the interface
#$primaryIP = "{primaryIP}"
#$primarySNM = "{primarySNM}"

# Set this to true if you wanted to delete the primary IP address and re-add it with SkipAsSource flag set to false, default is false
# This will ensure at least one IP is used for outbound traffic.
#$ReAddPrimaryIP = "{ReAddPrimaryIP}"

# Set this to true if you are automating this script and do not want it to wait for user input, default is true
#$SlientRun = "{SlientRun}"

# Specify the name of the logfile if you want to output the log to a file
#$logfile = "{logfile}"

# (Optional) Specify the location of bin if necessary
#$bin = {bin}

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
if ( ([string]::IsNullOrEmpty($netInterface)) -or ([string]::IsNullOrEmpty($primaryIP)) -or ([string]::IsNullOrEmpty($primarySNM)) )
{ 
	$scriptname = $MyInvocation.MyCommand.Name
	write-host "Invalid input detected, to use this script, you need to pass some argument to it." -foregroundcolor red
	write-host ".\$scriptname -netInterface [Name of the network interface] -PrimaryIP [Primary IP address of the NIC] -PrimarySNM [Subnet Mask of the primary IP]" -foregroundcolor red
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

# Set ReAddPrimaryIP to false if no user input
if ([string]::IsNullOrEmpty($ReAddPrimaryIP))
{
    $ReAddPrimaryIP = 'false'
}

# Set SlientRun to true if no user input
if ([string]::IsNullOrEmpty($SlientRun))
{
    $SlientRun = 'true'
}

# Generate a session ID if there is none
if ([string]::IsNullOrEmpty($SessionID))
{
    $SessionID = $([guid]::NewGuid().ToString())
}

# Put a starting line in the log file to improve readability
log -logstring "************************ $cmd is triggered by $(whoami) ************************ " -app $cmd -logfile $logfile -sessionid $SessionID


# *****************************************************
# ****           	   Validation            	   ****
# *****************************************************

log -logstring "Validating the Primary IP address & subnet mask ..." -app $cmd -logfile $logfile -sessionid $SessionID

$isIpValid = [System.Net.IPAddress]::tryparse([string]$primaryIP, [ref]"1.1.1.1")
$isSNMValid = [System.Net.IPAddress]::tryparse([string]$primarySNM, [ref]"1.1.1.1")

if ($isIpValid -ne "true") {
    
   log-error -logstring "The primary address $primaryIP or subnet mask $primarySNM is not in a valid format, this is a fatal error, exiting the script" -app $cmd -logfile $logfile -sessionid $SessionID
   exit
}
else {
    
    log -logstring "The Primary address $primaryIP and subnet mask $primarySNM is in a valid format" -app $cmd -logfile $logfile -sessionid $SessionID
}

# Get the Win32_NetworkAdapter object that matches the $netInterface

log -logstring "Checking if $netInterface is a valid NIC on the system ..." -app $cmd -logfile $logfile -sessionid $SessionID

$netAdapter = Get-WmiObject Win32_NetworkAdapter -Filter “NetConnectionID = '$netInterface'”

if ([string]::IsNullOrEmpty($netAdapter)) {

    log-error -logstring "The network interface $netInterface is not a valid NIC in the system, this is a fatal error, exiting the script" -app $cmd -logfile $logfile -sessionid $SessionID
    exit
}
else {
    
    log -logstring "The network interface $netInterface is a valid NIC in the system" -app $cmd -logfile $logfile -sessionid $SessionID
}

# Get the corresponding network adapter configuration
log -logstring "Getting the network adapter configuration of $netInterface ..." -app $cmd -logfile $logfile -sessionid $SessionID

$netNAC = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter “Index = '$($netAdapter.Index)'”

# Check if the Primary IP set at the beginning of the script exist in the NIC configuration as this might cause issue if it doesn't exist
log -logstring "Checking if $primaryIP is an existing IP address in $netInterface ..." -app $cmd -logfile $logfile -sessionid $SessionID

if ($netNAC.IPAddress -contains $primaryIP) {

    log -logstring "IP Address $primaryIP exist in $netInterface NIC config" -app $cmd -logfile $logfile -sessionid $SessionID

    # Check whether the subnet mask set at the beginning of the script matches the one in the system
    log -logstring "Validating the corresponding Subnet mask of $PrimaryIP ..." -app $cmd -logfile $logfile -sessionid $SessionID
    $i = [array]::IndexOf($netNAC.IPAddress,$primaryIP)
    If ($primarySNM -ne $netNAC.IPSubnet[$i]) {
        
        log-error -logstring "The subnet mask of $PrimaryIP in $netInterface is not $PrimarySNM, this is a fatal error, exiting the script now" -app $cmd -logfile $logfile -sessionid $SessionID
        exit
    }
    else {
        
        log -logstring "The subnet mask of primary IP address $PrimarySNM matches the subnet mask of $PrimaryIP in $netInterface" -app $cmd -logfile $logfile -sessionid $SessionID
    }
}
else {
    
    log-error -logstring "IP address $primaryIP does not exist in $netInterface NIC config, this is a fatal error, exiting the script now" -app $cmd -logfile $logfile -sessionid $SessionID
    exit
}


# *****************************************************
# ****            Start of the Script              ****
# *****************************************************

# load the matching sets of IP addresses and subnet masks into an array of PSObjects

$IPs = @()

0..($netNAC.IPAddress.count – 1) | Where-Object {$netNAC.IPAddress[$_].ToString() -ne $primaryIP -and $netNAC.IPAddress[$_].ToString() -like “*.*.*.*”} | ForEach-Object {

    $temp = New-Object PSObject -Property @{

        IPAddress = $netNAC.IPAddress[$_].ToString()
        IPSubnet = $netNAC.IPSubnet[$_].ToString()
    }

    $IPs += $temp
}

# Check if there is any additional IP address on the NIC

if ($IPs.Count -eq 0) {

    log -logstring "$netInterface does not contain any additional IP address, no more action required" -app $cmd -logfile $logfile -sessionid $SessionID
    exit
}

# List all the additional IP address on the NIC

log -logstring "Here is the list of additional IP address(es) found on $netInterface" -app $cmd -logfile $logfile -sessionid $SessionID
# log -logstring "IPAddress / Subnet"  -app $cmd -logfile $logfile -sessionid $SessionID
$IPlist = "IPaddress / Subnet: " 
foreach ($IP in $IPs) {

    #log -logstring "$($IP.IPAddress) / $($IP.IPSubnet)" -app $cmd -logfile $logfile -sessionid $SessionID
    $IPlist = $IPlist + "$($IP.IPAddress) / $($IP.IPSubnet), "
}
$IPlist = $IPlist.Substring(0,$IPlist.Length-2)
log -logstring $IPlist -app $cmd -logfile $logfile -SessionID $SessionID

if ($SlientRun -ne 'True') {
    
    $Checker = Read-host "Do you wish to continue to re-add them and set the skipassource flag to false? Y/N"
    
    if (($Checker -ne 'y') -and ($Checker -ne 'yes')) {

        log -logstring "$(whoami) decided to not go ahead with re-add IP operation, exiting the script now" -app $cmd -logfile $logfile -sessionid $SessionID
        exit
    }
}

# Now on to the core of the script, implementing SkipAsSource

# If the Re-add primary IP option is set to true, we are going to re-add the primary IP to make sure skipassource flag is set to false

If ($ReAddPrimaryIP -eq 'true') {
    
    log -logstring "Re-add primary IP address option is used, going to remove $primaryIP on $netInterface ..." -app $cmd -logfile $logfile -sessionid $SessionID
    $removeresult = netsh int ipv4 delete address $netInterface $primaryIP
    if ($?) {  
        
        log -logstring "$primaryIP is removed from $netInterface, re-adding it with the skipassource flag set to false ..." -app $cmd -logfile $logfile -sessionid $SessionID
        $readdresult = netsh int ipv4 add address “$netInterface” $primaryIP $primarySNM skipassource=false
        if ($?) {

            log -logstring "$primaryIP is re-added to $netInterface with the skipassource flag set to false" -app $cmd -logfile $logfile -sessionid $SessionID
        }
        else {
            
            log-error -logstring "$readdresult" -app $cmd -logfile $logfile -sessiondID $SessionID            
            log-error -logstring "Failed to re-add $PrimaryIP on $netInterface, this is a fatal error, exiting the script now" -app $cmd -logfile $logfile -sessionid $SessionID
            exit 
        }
    }
    else {
        
        log-error -logstring "$removeresult" -app $cmd -logfile $logfile -sessionid $SessionID
        log-error -logstring "Failed to remove $PrimaryIP on $netInterface, this is a fatal error, exiting the script now" -app $cmd -logfile $logfile -sessionid $SessionID
        exit
    }
}

# delete all no-primary IP address on the NIC and re-add them with skipassource flag set to true

$ErrCounter = 0

foreach ($ip in $IPs) {
 
    # delete the IP
    log -logstring "removing $($ip.IPAddress) from $netinterface ..." -app $cmd -logfile $logfile -sessionid $SessionID
    $removeresult = netsh int ipv4 delete address $netinterface $($ip.IPAddress)
    if ($?) {
        
        log -logstring "$($ip.IPAddress) is removed from $netinterface" -app $cmd -logfile $logfile -sessionid $SessionID
        
        # add the IP with SkipAsSource set to True
        log -logstring "re-adding $($ip.IPAddress) with skipassource flag set to True" -app $cmd -logfile $logfile -sessionid $SessionID
        $readdresult = netsh int ipv4 add address $netinterface $($ip.IPAddress) $($ip.IPSubnet) skipassource=true
        if ($?) {
            
            log -logstring "$($ip.IPAddress) is re-added to $netInterface and skipassource flag is set to true" -app $cmd -logfile $logfile -sessionid $SessionID
        }
        else {
            
            log-error -logstring "$readdresult" -app $cmd -logfile $logfile -SessionID $SessionID
            log-error -logstring "Failed to re-add $($IP.IPAddress) to $netInterface" -app $cmd -logfile $logfile -sessionid $SessionID
            $ErrCounter ++
        }
    }
    else {
        
        log-error -logstring "$removeresult" -app $cmd -logfile $logfile -SessionID $SessionID
        log-error -logstring "Failed to remove $($ip.IPAddress) from $netInterface" -app $cmd -logfile $logfile -sessionid $SessionID
        $ErrCounter ++
    }
}

log -logstring "Showing the list of IP on $netInterface to review the change" -app $cmd -logfile $logfile -sessionid $SessionID

# write a summary of the list of ip for audit purpose
$report = netsh int ipv4 show ipaddresses interface=$netInterface
log -logstring $report -app $cmd -logfile $logfile -sessionid $SessionID

if ($SlientRun -ne 'True') {
    
    $OutputReport = Read-Host "If you would like the list of IP output to a file, please enter the file name now e.g. ReAddIP_Report.txt"

    # write report to file
    If ( -not ([string]::IsNullOrEmpty($OutputReport))) {
    
        $report | Out-File $OutputReport
    }
}

if ($ErrCounter -gt 0) {

    log -logstring "Job completed with some Error(s), please review the log" -app $cmd -logfile $logfile -sessionid $SessionID
}
