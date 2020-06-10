# Auto-module import code from:
# https://4sysops.com/archives/use-pester-to-test-a-powershell-module/
$ThisModule = $MyInvocation.MyCommand.Path -replace '\.Tests\.ps1$'
$ThisModuleName = $ThisModule | Split-Path -Leaf
Get-Module -Name $ThisModuleName -All | Remove-Module -Force -ErrorAction Ignore
Import-Module -Name "$ThisModule.psm1" -Force -ErrorAction Stop

Describe $ThisModuleName {
	BeforeAll {
		Mock -ModuleName $ThisModuleName -CommandName Write-Host -MockWith { }

		function script:ShouldSuccess {
			Param (
				[ValidateNotNullOrEmpty()]
				[System.Collections.Hashtable] $Value,
				[string] $RawValue = "hello"
			)
			$Value."Success" | Should -Be $True
			$Value."DidError" | Should -Be $False
			$Value."CurrentError" | Should -Be $null
			$Value."Value" | Should -Be $RawValue
		}

		function script:New-SampleErrorRecord {
			$ErrorMessage = "Hello"
			$SampleErrorId = "Test"
			$SampleException = New-Object -TypeName System.Exception -ArgumentList $ErrorMessage
			$SampleErrorCategory = [System.Management.Automation.ErrorCategory]::OpenError
			$SampleTargetObject = 'UnknownHost'
			New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $SampleException, $SampleErrorId, $SampleErrorCategory, $SampleTargetObject
		}

		function script:Assert-ModuleMockCalled {
			return Assert-MockCalled -ModuleName $ThisModuleName @Args
		}
	}

	Describe 'Write-TrInfo' {
		It "Should print an info message" {
			Write-TrInfo "Hello" -Scope It
			Assert-ModuleMockCalled -CommandName Write-Host -Exactly 2
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -eq "[INFO]" } -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -like "*Hello*" } -Scope It
		}
	}

	Describe 'Write-TrWarn' {
		It "Should print a warning message" {
			Write-TrWarn "Hello" -Scope It
			Assert-ModuleMockCalled -CommandName Write-Host -Exactly 2
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -eq "[WARN]" } -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -like "*Hello*" } -Scope It
		}
	}

	Describe 'Write-TrHint' {
		It "Should print a hint message" {
			Write-TrHint "Hello"
			Assert-ModuleMockCalled Write-Host -Exactly 2 -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -eq "[HINT]" } -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -like "*Hello*" } -Scope It
		}
	}

	Describe 'Write-TrError' {
		It "Should print an error message" {
			$Sample = script:New-SampleErrorRecord
			Write-TrError $Sample
			Assert-ModuleMockCalled Write-Host -Exactly 2 -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -eq "[ERROR]" } -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -like "*Hello*" } -Scope It
		}
	}

	Describe 'Write-TrInvalid' {
		It "Should print an invalid message" {
			Write-TrInvalid "Hello"
			Assert-ModuleMockCalled Write-Host -Exactly 2 -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -eq "[INVALID]" } -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -like "*Hello*" } -Scope It
		}
		It "Should handle Got and Expected" {
			$Got = "Foo"
			$Expected = "Bar"
			Write-TrInvalid -Got $Got -Expected $Expected
			Assert-ModuleMockCalled Write-Host -Exactly 2 -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -like "*$Got*" } -Scope It
			Assert-ModuleMockCalled Write-Host -Exactly 1 -ParameterFilter { $Object -like "*$Expected*" } -Scope It
		}
	}

	Describe 'Invoke-TrCommand' {
		BeforeAll {
			function Invoke-MeForTesting { }
		}

		It "Should successfully invoke a command" {
			Mock -CommandName Invoke-MeForTesting -MockWith { "hello" }
			$Value = Invoke-TrCommand {
				Invoke-MeForTesting -ErrorAction Stop
			}
			Assert-MockCalled Invoke-MeForTesting -Exactly 1 -Scope It
			ShouldSuccess $Value
		}

		It "Should fail to invoke a command with a throw" {
			Mock -CommandName Invoke-MeForTesting -MockWith { throw "Error" }
			{ Invoke-TrCommand -Fatal:$True {
					Invoke-MeForTesting -EA Stop
				} } | Should -Throw
			Assert-MockCalled Invoke-MeForTesting -Exactly 1 -Scope It
		}
	}

	Describe 'Invoke-TrRetry' {
		BeforeAll {
			function Invoke-MeForTesting { }
			Mock -CommandName Start-Sleep -MockWith { }
			Mock -CommandName Write-TrError -MockWith { }
			Mock -CommandName Write-TrInfo -MockWith { }
		}

		It "Should successfully invoke a command" {
			Mock -CommandName Invoke-MeForTesting -MockWith { "hello" }
			$Value = Invoke-TrRetry -RetryCount 0 {
				Invoke-MeForTesting -ErrorAction Stop
			}
			Assert-MockCalled Invoke-MeForTesting -Exactly 1 -Scope It
			ShouldSuccess $Value
		}

		It "Should fail to invoke a command with a throw" {
			Mock -CommandName Invoke-MeForTesting -MockWith { throw "Error" }
			{ Invoke-TrRetry -Fatal:$True -RetryCount 0 {
					Invoke-MeForTesting -EA Stop
				} } | Should -Throw
			Assert-MockCalled Invoke-MeForTesting -Exactly 1 -Scope It
		}

		It "Should fail to invoke a command with a throw and a retry" {
			Mock -CommandName Invoke-MeForTesting -MockWith { throw "Error" }
			{ Invoke-TrRetry -Fatal:$True -RetryCount 3 -RetryWait 1 {
					Invoke-MeForTesting -EA Stop
				} } | Should -Throw
			Assert-MockCalled Invoke-MeForTesting -Exactly 4 -Scope It
			Assert-MockCalled Start-Sleep -Exactly 4 -Scope It
			Assert-MockCalled Write-TrError -Exactly 4 -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 4 -ParameterFilter { $Message -like "*Waiting 1 seconds...*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 0 -ParameterFilter { $Message -like "*Retry attempt 0 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 1 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 1 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 2 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 3 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 0 -ParameterFilter { $Message -like "*Retry attempt 4 of 3*" } -Scope It
		}

		It "Should fail to invoke a command with a throw and a retry until success" {
			$Script:CounterForInvokeRetrySuccessTest = 0
			Mock -CommandName Invoke-MeForTesting -MockWith {
				if ($Script:CounterForInvokeRetrySuccessTest -lt 3) {
					$Script:CounterForInvokeRetrySuccessTest++
					Throw "Error"
				}
				Return "I ran!"
			}
			$Result = Invoke-TrRetry -Fatal:$True -RetryCount 3 -RetryWait 1 {
				Invoke-MeForTesting -EA Stop
			}
			Assert-MockCalled Invoke-MeForTesting -Exactly 4 -Scope It
			Assert-MockCalled Start-Sleep -Exactly 3 -Scope It
			Assert-MockCalled Write-TrError -Exactly 3 -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 3 -ParameterFilter { $Message -like "*Waiting 1 seconds...*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 0 -ParameterFilter { $Message -like "*Retry attempt 0 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 1 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 1 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 2 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 1 -ParameterFilter { $Message -like "*Retry attempt 3 of 3*" } -Scope It
			Assert-ModuleMockCalled Write-TrInfo -Exactly 0 -ParameterFilter { $Message -like "*Retry attempt 4 of 3*" } -Scope It

			ShouldSuccess $Result "I ran!"
		}
	}
}
