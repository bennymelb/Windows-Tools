param ( [string]$zipfile, [string]$destination )

if ( !(Test-path $destination) ) 
{
		write-host "$destination does not exist, creating it"
		New-Item -ItemType directory -path $destination
}

$shell = new-object -com shell.application
$zip = $shell.NameSpace("$zipfile")
foreach($item in $zip.items()) 
{ 
	$shell.Namespace("$destination").copyhere($item) 
}

