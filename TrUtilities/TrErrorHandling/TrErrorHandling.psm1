#=========================================#
#																				 #
# Flow control and error handling				 #
#																				 #
#=========================================#

<#
.SYNOPSIS

Given a string message write an info message to the screen

.PARAMETER Message

The content of the message

.LINK

Write-Host
#>
function Write-TrInfo {
	Param (
		[ValidateNotNullOrEmpty()]
		[string] $Message
	)
	Write-Host "[INFO]" -ForegroundColor White -BackgroundColor Blue -NoNewline
	Write-Host " ${Message}."
}

<#
.SYNOPSIS

Given a string message write a hint message to the screen

.PARAMETER Message

The content of the message

.LINK

Write-Host
#>
function Write-TrHint {
	Param (
		[ValidateNotNullOrEmpty()]
		[string] $Message
	)
	Write-Host "[HINT]" -ForegroundColor White -BackgroundColor Blue -NoNewline
	Write-Host " $Message."
}

<#
.SYNOPSIS

Given an ErrorRecord write a friendly non-fatal error to the screen

.PARAMETER ErrorToFormat

This is the ErrorRecord that is to be formatted as a string

.PARAMETER Message

An optional custom message to use instead of the ErrorRecord

.LINK

Write-Host

.LINK

System.Management.Automation.ErrorRecord
#>
function Write-TrError {
	Param (
		[System.Management.Automation.ErrorRecord] $ErrorToFormat = { },
		[string] $Message = $Null
	)
	Write-Host "[ERROR]" -ForegroundColor White -BackgroundColor Red -NoNewline
	if ($Message) {
		Write-Host " ${Message}."
	} elseif ($ErrorToFormat) {
		Write-Host " $($ErrorToFormat.ToString())."
	} else {
		Write-Host " an unknown error has ocurred. Sorry."
	}
}

<#
.SYNOPSIS

Given a string message write an invalid message to the screen

.PARAMETER Message

The content of the message

.LINK

Write-Host
#>
function Write-TrInvalid {
	Param (
		[string] $Message = $Null,
		$Got = $Null,
		$Expected = $Null
	)
	Write-Host "[INVALID]" -ForegroundColor White -BackgroundColor Red -NoNewline
	if ($Message) {
		Write-Host " $($Message)"
	} else {
		Write-Host " Your input ('$Got') did not pass the $Expected test."
	}
}

<#
.SYNOPSIS

Given a Hashtable from Invoke-TrCommand add the retry fields

.DESCRIPTION

Take a Hashtable from Invoke-TrCommand and add two retry related
fields - AttemptCount and ElapsedTime

.PARAMETER ValueFromInvoke

This is the Hashtable that Invoke-TrCommand has emitted

.PARAMETER AttemptCounter

The number of retries undertaken before the result was obtained

.PARAMETER RetryWait

Length of time between retries in seconds

.LINK

Invoke-TrCommand

.LINK

Write-Host
#>
function Format-TrRetryHashtable {
	Param (
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable] $ValueFromInvoke,
		[ValidateNotNullOrEmpty()]
		[int] $AttemptCounter,
		[ValidateNotNullOrEmpty()]
		[int] $RetryWait
	)
	Return @{
		Success = $ValueFromInvoke."Success"
		DidError = $ValueFromInvoke."DidError"
		Error = $ValueFromInvoke."Error"
		Value = $ValueFromInvoke."Value"
		AttemptCount = $AttemptCounter
		ElapsedTime = $AttemptCounter * $RetryWait
	}
}

<#
.SYNOPSIS

Execute a process with error handling

.DESCRIPTION

Execute a process with error handling to make the output easier for users.
Errors can be converted to be non-fatal.

.PARAMETER Invoke

A script block that contains the script we want to execute with error handling

.PARAMETER ErrorMessage

An optional error message to be used instead of the exception print out

.PARAMETER Fatal

If set to truthy then the error is thrown, which causes the script to
exit early. Default is $False.

.LINK

Write-TrError

.LINK

Write-Host
#>
function Invoke-TrCommand {
	Param (
		[ValidateNotNullOrEmpty()]
		[scriptblock] $Invoke,
		[string] $ErrorMessage = $Null,
		[boolean] $Fatal = $False
	)
	$DidError = $False
	$LastError = $Error[0]
	$CurrentError = $Null
	$RawValue = $Null
	Try {
		$RawValue = &$Invoke
	} Catch {
		$DidError = $True
		$CurrentError = $Error[0]
	}
	# try to catch errored calls that aren't throwing exceptions
	if (-not $DidError -and (-not $? -or -not ($Error[0] -eq $LastError))) {
		$DidError = $True
		$CurrentError = $Error[0]
	}
	if ($DidError) {
		if ($Fatal) {
			Throw $CurrentError
		}
		if ($CurrentError."ErrorRecord") {
			Write-TrError -ErrorToFormat $CurrentError."ErrorRecord" -Message $ErrorMessage
		} else {
			Write-TrError -ErrorToFormat $CurrentError -Message $ErrorMessage
		}
	}
	Return @{
		Success = (-not $DidError)
		DidError = $DidError
		Error = $CurrentError
		Value = $RawValue
	}
}

<#
.SYNOPSIS

Execute a process with error handling and retry on failure

.DESCRIPTION

Execute a process with error handling to make the output easier for users.
Errors can be converted to be non-fatal.

When an error is encountered the process can be automatically retried with an
optional wait interval between attempts.

.PARAMETER Invoke

A script block that contains the script we want to execute with error handling

.PARAMETER ErrorMessage

An optional error message to be used instead of the exception print out

.PARAMETER RetryCount

How many attempts to perform before giving up

.PARAMETER RetryWait

The period of time between attempts in seconds

.PARAMETER Fatal

If set to truthy then the error is thrown, which causes the script to
exit early. Default is $False.

.LINK

Invoke-TrCommand

.LINK

Write-TrError

.LINK

Write-Host
#>
function Invoke-TrRetry {
	Param (
		[ValidateNotNullOrEmpty()]
		[scriptblock] $Invoke,
		[string] $ErrorMessage = $Null,
		[ValidateNotNullOrEmpty()]
		[int] $RetryCount = 0,
		[ValidateNotNullOrEmpty()]
		[int] $RetryWait = $Null,
		[boolean] $Fatal = $False
	)
	$AttemptCounter = 0
	$StopLooping = $False
	$Value = $Null
	Do {
		if ($AttemptCounter -gt 0) {
			Write-TrInfo "Retry attempt ${AttemptCounter} of ${RetryCount}"
		}
		$AttemptCounter++
		$Value = Invoke-TrCommand `
			-Invoke $Invoke `
			-Fatal:$False
		if ($Value."Success") {
			Return Format-TrRetryHashtable `
				$Value `
				$AttemptCounter `
				$RetryWait
		}
		if ($RetryWait) {
			Write-TrInfo "Waiting ${RetryWait} seconds..."
			Start-Sleep -Seconds $RetryWait
		}
	} Until (($AttemptCounter -ge ($RetryCount + 1)) -or ($StopLooping))
	if ($Value."DidError") {
		if ($Fatal) {
			Throw $Value."Error"
		}
		Write-TrError $Value."Error" $ErrorMessage
	}
	Return Format-TrRetryHashtable `
		$Value `
		$AttemptCounter `
		$RetryWait
}


<#
.SYNOPSIS

Converts a non-fatal error into a fatally thrown error

.PARAMETER InvokeResponse

The response object from Invoke-TrCommand or Invoke-TrRetry

.LINK

Invoke-TrCommand

.LINK

Write-TrError

.LINK

Write-Host
#>
function Write-TrInvokeToFatal {
	Param (
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable] $InvokeResponse
	)
	if ($InvokeResponse."DidError") {
		Throw $InvokeResponse."Error"
	}
}

<#
.SYNOPSIS

Execute a process with success or failed output to user

.DESCRIPTION

Execute a process with error handling that will show success or failed depending
upon the success of the process

.PARAMETER Invoke

A script block that contains the script we want to execute with error handling

.PARAMETER Prompt

The text to display before attempting the operation

.PARAMETER ReturnValue

Should it return the success value instead of the default of $True on success

.LINK

Invoke-TrCommand

.LINK

Write-TrError

.LINK

Write-Host
#>
function Invoke-TrSuccessOrFailed {
	Param (
		[ValidateNotNullOrEmpty()]
		[scriptblock] $Invoke,
		[ValidateNotNullOrEmpty()]
		[string] $Prompt,
		[boolean] $ReturnValue = $False
	)
	Write-Host $Prompt -NoNewline
	$Result = Invoke-TrCommand $Invoke
	if ($Result."Success") {
		Write-Host " Success." -ForegroundColor Green
		if ($ReturnValue) {
			Return $Result."Value"
		}
		Return $True
	}
	Write-Host " Failed." -ForegroundColor Red
	Return $False
}
