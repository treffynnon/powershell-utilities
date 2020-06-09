<#
Export-ModuleMember Write-TrInfo
Export-ModuleMember Write-TrHint
Export-ModuleMember Write-TrInvalid
Export-ModuleMember Write-TrError
Export-ModuleMember Invoke-TrCommand
Export-ModuleMember Invoke-TrRetry
Export-ModuleMember Write-TrInvokeToFatal
Export-ModuleMember Invoke-TrSuccessOrFailed

Export-ModuleMember Confirm-TrValidEmailAddress
Export-ModuleMember Confirm-TrValidMachineName
Export-ModuleMember Confirm-TrValidGuid
Export-ModuleMember Read-TrUserInput
#>

$ModuleName = "Tr"
$Author = "Simon Holywell"
$Tags = "Treffynnon", "PowerShell", "Utilities"
$ModuleVersion = "1.0.0.0"
$PowerShellVersion = "4.0.0"
$Description = "Utilities for writing PowerShell scripts"
$CopyRight = @"
Copyright 2020 Simon Holywell

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"@
$LicenseURI = "https://www.apache.org/licenses/LICENSE-2.0.html"
$ProjectURI = "https://www.simonholywell.com"
$RequiredAssemblies = ''
$NestedModules = @(
	".\Tr.psm1",
	".\TrUserInput\TrUserInput.psm1",
	".\TrErrorHandling\TrErrorHandling.psm1"
)
$FunctionsToExport = @(
	"Write-TrInfo",
	"Write-TrHint",
	"Write-TrInvalid",
	"Write-TrError",
	"Invoke-TrCommand",
	"Invoke-TrRetry",
	"Write-TrInvokeToFatal",
	"Invoke-TrSuccessOrFailed",
	"Confirm-TrValidEmailAddress",
	"Confirm-TrValidMachineName",
	"Confirm-TrValidGuid",
	"Read-TrUserInput"
)
$CmdletsToExport = @()
$AliasesToExport = @()

New-ModuleManifest `
	-RootModule "$ModuleName.psm1" `
	-Path .\$ModuleName.psd1 `
	-Guid ([guid]::NewGuid()) `
	-RequiredAssemblies $RequiredAssemblies `
	-Author $Author `
	-ModuleVersion $ModuleVersion `
	-Description $Description `
	-Copyright $CopyRight `
	-NestedModules $NestedModules `
	-FunctionsToExport $FunctionsToExport `
	-Tags $Tags `
	-PowerShellVersion $PowerShellVersion `
	-LicenseUri $LicenseURI `
	-ProjectUri $ProjectURI `
	-AliasesToExport $AliasesToExport `
	-CmdletsToExport $CmdletsToExport