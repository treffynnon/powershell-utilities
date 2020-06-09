# Auto-module import code from:
# https://4sysops.com/archives/use-pester-to-test-a-powershell-module/
$ThisModule = $MyInvocation.MyCommand.Path -replace '\.Tests\.ps1$'
$ThisModuleName = $ThisModule | Split-Path -Leaf
Get-Module -Name $ThisModuleName -All | Remove-Module -Force -ErrorAction Ignore
Import-Module -Name "$ThisModule.psm1" -Force -ErrorAction Stop

Describe $ThisModuleName {
	BeforeAll {
		function ListToThrow {
			Param (
				[Parameter(Mandatory = $True)]
				$List,
				[ValidateNotNullOrEmpty()]
				$Invoke
			)

			$List | ForEach-Object {
				{ &$Invoke $_ } | Should -Throw
			}
		}
		function ListToSucceed {
			Param (
				[Parameter(Mandatory = $True)]
				$List,
				[ValidateNotNullOrEmpty()]
				$Invoke
			)

			$List | ForEach-Object {
				{ &$Invoke $_ } | Should -Not -Throw
			}
		}
	}

	Describe 'Confirm-TrValidString' {
		It 'Should throw when not a string' {
			ListToThrow `
				($Null, "") `
				Confirm-TrValidString
		}
		It 'Should success on a string' {
			ListToSucceed `
				("toto", "localhost", "s@", ".@.com") `
				Confirm-TrValidString
		}
	}

	Describe 'Confirm-TrValidEmailAddress' {
		It 'Should error on an invalid email address' {
			ListToThrow `
				("", "toto", "localhost", "s@", ".@.com") `
				Confirm-TrValidEmailAddress
		}
		It 'Should success on a valid email address' {
			ListToSucceed `
				("s@s.com", "foo@example.org", "m@far.co.uk", "s@localhost") `
				Confirm-TrValidEmailAddress
		}
	}

	Describe 'Confirm-TrValidMachineName' {
		It 'Should error on an invalid machine name' {
			ListToThrow `
				("", "1", "::::", "d{*&gf}", "a@s.com") `
				Confirm-TrValidMachineName
		}
		It 'Should success on a valid machine name' {
			ListToSucceed `
				("localhost", "my-machine", "nam_e") `
				Confirm-TrValidMachineName
		}
	}

	Describe 'Confirm-TrValidGuid' {
		It 'Should error on an invalid GUID' {
			ListToThrow `
				("", "1", "::::", "d{*&gf}", "a@s.com") `
				Confirm-TrValidGuid
		}
		It 'Should success on a valid GUID' {
			ListToSucceed `
				((New-Guid), (New-Guid), (New-Guid), (New-Guid), (New-Guid), (New-Guid)) `
				Confirm-TrValidGuid
		}
	}

	Describe 'Read-TrUserInput' {
		BeforeAll {
			Mock -CommandName Write-Host -MockWith { }
		}
		It 'Should be able to read and validate some user input' {
			Mock -CommandName Read-Host -MockWith { "s@h.com" }
			$Email = Read-TrUserInput `
				"What's your email address?" `
				Confirm-TrValidEmailAddress
			Assert-MockCalled Read-Host -Exactly 1
			$Email | Should -Be "s@h.com"
		}
		It 'Should request input until it passes validation' {
			$Script:CounterForReadUserInputSuccessTest = 0
			Mock -CommandName Read-Host -MockWith {
				if ($Script:CounterForReadUserInputSuccessTest -lt 3) {
					$Script:CounterForReadUserInputSuccessTest++
					Return $Script:CounterForReadUserInputSuccessTest
				}
				Return "s@h.com"
			}
			$Email = Read-TrUserInput `
				"What's your email address?" `
				Confirm-TrValidEmailAddress
			Assert-MockCalled Read-Host -Exactly 4
			$Email | Should -Be "s@h.com"
			Assert-MockCalled Write-Host -Exactly 1 -ParameterFilter { $Message -like "*('1') did not pass the Confirm-TrValidEmailAddress*" } -Scope It
			Assert-MockCalled Write-Host -Exactly 1 -ParameterFilter { $Message -like "*('2') did not pass the Confirm-TrValidEmailAddress*" } -Scope It
			Assert-MockCalled Write-Host -Exactly 1 -ParameterFilter { $Message -like "*('3') did not pass the Confirm-TrValidEmailAddress*" } -Scope It
			Assert-MockCalled Write-Host -Exactly 0 -ParameterFilter { $Message -like "*('4') did not pass the Confirm-TrValidEmailAddress*" } -Scope It
		}
	}
}