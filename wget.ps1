# This is a simply powershell script to download file via http using a simply webclient object

param ( [string]$source, [string]$destination, [string]$username, [string]$password ,[string]$quiet )

# Set the quiet switch to yes by default if no user input
if ( !$quiet )
{
	$quiet="yes"
}

# If username is set but no password, throw an error and vice versa
if ( (($username) -and (!$password)) -or ((!$username) -and ($password)) )
{
	Write-host "Error !!! You need to enter both the username & password"
}

# Check if the destination file already exist
if ( test-path $destination)
{
	if ( ($quiet -eq "yes") -or ($quiet -eq "y") )
	{
		write-host "$destination exist, going to overwrite the file"
	}
	else
	{
		$overwirte = read-host -prompt "$destination exist, do you want to overwrite the file? Yes/No"
		if ( ($overwrite -eq "no") -or ($overwrite -eq "n") )
		{
			write-host "Aborting the download"
			exit
		}
	}
}

# Create a webclient object to handle the http download
$client = new-object System.Net.WebClient

# Set up the username & password if it present
if (($username) -and ($password))
{
	$credentialAsBytes = [System.Text.Encoding]::ASCII.GetBytes($userName + ":" + $password)
	$credentialAsBase64String = [System.Convert]::ToBase64String($credentialAsBytes)
	$webClient.Headers[[System.Net.HttpRequestHeader]::Authorization] = "Basic " + $credentialAsBase64String
}
	
# Download the file
Try
{
	$client.DownloadFile($source, $destination)
}
Catch
{
	$ErrorMessage = $_.Exception.Message
	write-host "Error downloading $destination"
	write-host "$ErrorMessage"
}

if (!$ErrorMessage)
{
	write-host "Successfully downloaded $destination"
}
