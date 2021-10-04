﻿# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Pester testing file')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Pester testing file')]
[CmdletBinding()]
param()
BeforeAll {
    . $PSScriptRoot\..\..\..\.build\BuildFunctions\Get-ExpandedScriptContent.ps1
    . $PSScriptRoot\..\Helpers\Class.ps1
    $Script:parentPath = (Split-Path -Parent $PSScriptRoot)
    $Script:PesterExtract = "# Extract for Pester Testing - Start"
}

Describe "Testing Health Checker by Mock Data Imports" {

    BeforeAll {
        . $PSScriptRoot\HealthCheckerTests.ImportCode.NotPublished.ps1
        $Script:Server = $env:COMPUTERNAME
        $Script:MockDataCollectionRoot = "$Script:parentPath\Tests\DataCollection\E19"
        . $PSScriptRoot\HealthCheckerTest.CommonMocks.NotPublished.ps1
    }

    Context "Basic Exchange 2019 CU11 Testing HyperV" {
        BeforeAll {
            $hc = Get-HealthCheckerExchangeServer
            $hc | Export-Clixml $PSScriptRoot\Debug_HyperV_Results.xml -Depth 6 -Encoding utf8
            $Script:results = Invoke-AnalyzerEngine $hc
        }

        It "Display Results - Exchange Information" {
            SetActiveDisplayGrouping "Exchange Information"

            TestObjectMatch "Name" $env:COMPUTERNAME
            TestObjectMatch "Version" "Exchange 2019 CU11"
            TestObjectMatch "Build Number" "15.2.986.5"
            TestObjectMatch "Server Role" "Mailbox"
            TestObjectMatch "DAG Name" "Standalone Server"
            TestObjectMatch "AD Site" "Default-First-Site-Name"
            TestObjectMatch "MAPI/HTTP Enabled" "True"
            TestObjectMatch "Exchange Server Maintenance" "Server is not in Maintenance Mode" -WriteType "Green"
            $Script:ActiveGrouping.Count | Should -Be 9
        }

        It "Display Results - Operating System Information" {
            SetActiveDisplayGrouping "Operating System Information"

            TestObjectMatch "Version" "Microsoft Windows Server 2019 Datacenter"
            TestObjectMatch "Time Zone" "Pacific Standard Time"
            TestObjectMatch "Dynamic Daylight Time Enabled" "True"
            TestObjectMatch ".NET Framework" "4.8" -WriteType "Green"
            TestObjectMatch "Power Plan" "Balanced --- Error" -WriteType "Red"
            TestObjectMatch "Http Proxy Setting" "<None>"
            TestObjectMatch "Visual C++ 2012" "184610406 Version is current" -WriteType "Green"
            TestObjectMatch "Visual C++ 2013" "Redistributable is outdated" -WriteType "Yellow"
            TestObjectMatch "Server Pending Reboot" $false

            $pageFile = GetObject "Page File Size"
            $pageFile.TotalPhysicalMemory | Should -Be 6442450944
            $pageFile.MaxPageSize | Should -Be 0
            $pageFile.MultiPageFile | Should -Be $false
            $pageFile.RecommendedPageFile | Should -Be 0

            $Script:ActiveGrouping.Count | Should -Be 12
        }

        It "Display Results - Process/Hardware Information" {
            SetActiveDisplayGrouping "Processor/Hardware Information"

            TestObjectMatch "Type" "HyperV"
            TestObjectMatch "Processor" "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"
            TestObjectMatch "Number of Processors" 1
            TestObjectMatch "Number of Physical Cores" 2 -WriteType "Green"
            TestObjectMatch "Number of Logical Cores" 4 -WriteType "Green"
            TestObjectMatch "All Processor Cores Visible" "Passed" -WriteType "Green"
            TestObjectMatch "Max Processor Speed" 2200
            TestObjectMatch "Physical Memory" 6 -WriteType "Yellow"

            $Script:ActiveGrouping.Count | Should -Be 9
        }

        It "Display Results - NIC Settings" {
            SetActiveDisplayGrouping "NIC Settings Per Active Adapter"

            TestObjectMatch "Interface Description" "Microsoft Hyper-V Network Adapter [Ethernet]"
            TestObjectMatch "Driver Date" "2006-06-21"
            TestObjectMatch "MTU Size" 1500
            TestObjectMatch "Max Processors" 2
            TestObjectMatch "Max Processor Number" 2
            TestObjectMatch "Number of Receive Queues" 2
            TestObjectMatch "RSS Enabled" "True" -WriteType "Green"
            TestObjectMatch "Link Speed" "10000 Mbps"
            TestObjectMatch "IPv6 Enabled" "True"
            TestObjectMatch "Address" "192.168.11.11\24 Gateway: 192.168.11.1"
            TestObjectMatch "Registered In DNS" "True"
            TestObjectMatch "Packets Received Discarded" 0 -WriteType "Green"

            $Script:ActiveGrouping.Count | Should -Be 16
        }

        It "Display Results - Frequent Configuration Issues" {
            SetActiveDisplayGrouping "Frequent Configuration Issues"

            TestObjectMatch "TCP/IP Settings" 90000 -WriteType "Yellow"
            TestObjectMatch "RPC Min Connection Timeout" 0
            TestObjectMatch "FIPS Algorithm Policy Enabled" 0
            TestObjectMatch "CTS Processor Affinity Percentage" 0 -WriteType "Green"
            TestObjectMatch "Credential Guard Enabled" $false
            TestObjectMatch "EdgeTransport.exe.config Present" "True" -WriteType "Green"

            $Script:ActiveGrouping.Count | Should -Be 6
        }

        It "Display Results - Security Settings" {
            SetActiveDisplayGrouping "Security Settings"

            TestObjectMatch "LmCompatibilityLevel Settings" 3
            TestObjectMatch "SMB1 Installed" "False" -WriteType "Green"
            TestObjectMatch "SMB1 Blocked" "True" -WriteType "Green"
            TestObjectMatch "Exchange Emergency Mitigation Service" "Enabled" -WriteType "Green"
            TestObjectMatch "Windows service" "Running"
            TestObjectMatch "Pattern service" "200 - Reachable"
            TestObjectMatch "Telemetry enabled" "False"

            $Script:ActiveGrouping.Count | Should -Be 71
        }

        It "Display Results - Security Vulnerability" {
            SetActiveDisplayGrouping "Security Vulnerability"

            $cveTests = $Script:ActiveGrouping.TestingValue | Where-Object { $_.StartsWith("CVE") }
            $cveTests.Contains("CVE-2020-1147") | Should -Be $true
            $cveTests.Contains("CVE-2021-1730") | Should -Be $true
        }
    }

    Context "Basic Exchange 2019 CU11 Testing Physical" {
        BeforeAll {
            $Script:date = Get-Date
            Mock Get-WmiObjectHandler -ParameterFilter { $Class -eq "Win32_ComputerSystem" } `
                -MockWith { return Import-Clixml "$Script:MockDataCollectionRoot\Hardware\Physical_Win32_ComputerSystem.xml" }
            Mock Get-WmiObjectHandler -ParameterFilter { $Class -eq "Win32_PhysicalMemory" } `
                -MockWith { return Import-Clixml "$Script:MockDataCollectionRoot\Hardware\Physical_Win32_PhysicalMemory.xml" }
            Mock Get-WmiObjectHandler -ParameterFilter { $Class -eq "Win32_Processor" } `
                -MockWith { return Import-Clixml "$Script:MockDataCollectionRoot\Hardware\Physical_Win32_Processor.xml" }
            $hc = Get-HealthCheckerExchangeServer
            $hc | Export-Clixml $PSScriptRoot\Debug_Physical_Results.xml -Depth 6 -Encoding utf8
            $Script:results = Invoke-AnalyzerEngine $hc
        }

        It "Display Results - Operating System Information" {
            SetActiveDisplayGrouping "Operating System Information"

            $pageFile = GetObject "Page File Size"
            $pageFile.TotalPhysicalMemory | Should -Be 103079215104
        }

        It "Display Results - Process/Hardware Information" {
            SetActiveDisplayGrouping "Processor/Hardware Information"

            TestObjectMatch "Type" "Physical"
            TestObjectMatch "Number of Processors" 2 -WriteType "Green"
            TestObjectMatch "Number of Physical Cores" 12 -WriteType "Green"
            TestObjectMatch "Number of Logical Cores" 24 -WriteType "Green"
            TestObjectMatch "All Processor Cores Visible" "Failed" -WriteType "Red"
            TestObjectMatch "Max Processor Speed" 2201
            TestObjectMatch "Physical Memory" 96 -WriteType "Yellow"
            TestObjectMatch "Manufacturer" "My Custom PC"
            TestObjectMatch "Model" "CHG-GG"

            $Script:ActiveGrouping.Count | Should -Be 11
        }

        It "Display Results - NIC Settings" {
            SetActiveDisplayGrouping "NIC Settings Per Active Adapter"

            TestObjectMatch "Sleepy NIC Disabled" "True"

            $Script:ActiveGrouping.Count | Should -Be 18
        }
    }

    Context "Mocked Calls" {

        It "Testing Standard Mock Calls" {
            $Script:ErrorCount = 0
            Mock Invoke-CatchActions { $Script:ErrorCount++ }
            #redo change to a mock call for Exchange cmdlets
            Mock Get-ExchangeServer { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetExchangeServer.xml" }
            Mock Get-ExchangeCertificate { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetExchangeCertificate.xml" }
            Mock Get-AuthConfig { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetAuthConfig.xml" }
            Mock Get-ExSetupDetails { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\ExSetup.xml" }
            Mock Get-MailboxServer { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetMailboxServer.xml" }
            Mock Get-OwaVirtualDirectory { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetOwaVirtualDirectory.xml" }
            Mock Get-WebServicesVirtualDirectory { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetWebServicesVirtualDirectory.xml" }
            Mock Get-OrganizationConfig { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetOrganizationConfig.xml" }
            Mock Get-HybridConfiguration { return $null }
            Mock Get-Service { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetServiceMitigation.xml" }
            Mock Get-ServerComponentState { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetServerComponentState.xml" }
            Mock Test-ServiceHealth { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\TestServiceHealth.xml" }

            $Error.Clear()
            Get-HealthCheckerExchangeServer | Out-Null
            $Error.Count | Should -Be $Script:ErrorCount
            # Hard coded to know if this ever changes.
            Assert-MockCalled Invoke-CatchActions -Exactly 1

            Assert-MockCalled Get-ExchangeAdSchemaClass -Exactly 1
            Assert-MockCalled Get-WmiObjectHandler -Exactly 6
            Assert-MockCalled Invoke-ScriptBlockHandler -Exactly 6
            Assert-MockCalled Get-RemoteRegistryValue -Exactly 8
            Assert-MockCalled Get-NETFrameworkVersion -Exactly 1
            Assert-MockCalled Get-DotNetDllFileVersions -Exactly 1
            Assert-MockCalled Get-NicPnpCapabilitiesSetting -Exactly 1
            Assert-MockCalled Get-NetIPConfiguration -Exactly 1
            Assert-MockCalled Get-DnsClient -Exactly 1
            Assert-MockCalled Get-NetAdapterRss -Exactly 1
            Assert-MockCalled Get-HotFix -Exactly 1
            Assert-MockCalled Get-CounterSamples -Exactly 1
            Assert-MockCalled Get-ServerRebootPending -Exactly 1
            Assert-MockCalled Get-TimeZoneInformationRegistrySettings -Exactly 1
            Assert-MockCalled Get-AllTlsSettingsFromRegistry -Exactly 1
            Assert-MockCalled Get-CredentialGuardEnabled -Exactly 1
            Assert-MockCalled Get-Smb1ServerSettings -Exactly 1
            Assert-MockCalled Get-ExchangeAppPoolsInformation -Exactly 1
            Assert-MockCalled Get-ExchangeApplicationConfigurationFileValidation -Exactly 1
            Assert-MockCalled Get-ExchangeUpdates -Exactly 1
            Assert-MockCalled Get-ExchangeAdSchemaClass -Exactly 1
            Assert-MockCalled Get-ExchangeServer -Exactly 1
            Assert-MockCalled Get-ExchangeCertificate -Exactly 1
            Assert-MockCalled Get-AuthConfig -Exactly 1
            Assert-MockCalled Get-ExSetupDetails -Exactly 1
            #Need to change this as we shouldn't be calling Get-MailboxServer twice
            Assert-MockCalled Get-MailboxServer -Exactly 2
            Assert-MockCalled Get-OwaVirtualDirectory -Exactly 1
            Assert-MockCalled Get-WebServicesVirtualDirectory -Exactly 1
            Assert-MockCalled Get-OrganizationConfig -Exactly 1
            Assert-MockCalled Get-HybridConfiguration -Exactly 1
            Assert-MockCalled Get-Service -Exactly 1
            Assert-MockCalled Get-ServerComponentState -Exactly 1
            Assert-MockCalled Test-ServiceHealth -Exactly 1
        }
    }

    Context "Checking Scenarios 1" {
        BeforeAll {
            Mock Get-RemoteRegistryValue -ParameterFilter { $GetValue -eq "KeepAliveTime" } -MockWith { return 0 }
            Mock Get-RemoteRegistryValue -ParameterFilter { $GetValue -eq "CtsProcessorAffinityPercentage" } -MockWith { return 10 }
            Mock Get-CredentialGuardEnabled -MockWith { return $true }
            Mock Get-ExchangeApplicationConfigurationFileValidation { return Import-Clixml "$Script:MockDataCollectionRoot\Exchange\GetExchangeApplicationConfigurationFileValidation1.xml" }
            Mock Get-ServerRebootPending { return Import-Clixml "$Script:MockDataCollectionRoot\OS\GetServerRebootPending1.xml" }
            Mock Get-AllTlsSettingsFromRegistry { return Import-Clixml "$Script:MockDataCollectionRoot\OS\GetAllTlsSettingsFromRegistry1.xml" }
            Mock Get-Smb1ServerSettings { return Import-Clixml "$Script:MockDataCollectionRoot\OS\GetSmb1ServerSettings1.xml" }

            $hc = Get-HealthCheckerExchangeServer
            $hc | Export-Clixml $PSScriptRoot\Debug_Scenario1_Results.xml -Depth 6 -Encoding utf8
            $Script:results = Invoke-AnalyzerEngine $hc
        }

        It "TCP Keep Alive Time" {
            SetActiveDisplayGrouping "Frequent Configuration Issues"
            TestObjectMatch "TCP/IP Settings" 0 -WriteType "Red"
        }

        It "CTS Processor Affinity Percentage" {
            TestObjectMatch "CTS Processor Affinity Percentage" 10 -WriteType "Red"
        }

        It "Credential Guard Enabled" {
            TestObjectMatch "Credential Guard Enabled" "True" -WriteType "Red"
        }

        It "EdgeTransport.exe.config Present" {
            TestObjectMatch "EdgeTransport.exe.config Present" "False --- Error" -WriteType "Red"
        }

        It "Server Pending Reboot" {
            SetActiveDisplayGrouping "Operating System Information"
            TestObjectMatch "Server Pending Reboot" "True" -WriteType "Yellow"
        }

        It "TLS Settings" {
            SetActiveDisplayGrouping "Security Settings"
            TestObjectMatch "TLS 1.1 - Mismatch" "True" -WriteType "Red"
            TestObjectMatch "TLS 1.1 - SystemDefaultTlsVersions Error" "True" -WriteType "Red"
            TestObjectMatch "Detected TLS Mismatch Display More Info" "True" -WriteType "Yellow"
        }

        It "SMB Settings" {
            TestObjectMatch "SMB1 Installed" "True" -WriteType "Red"
            TestObjectMatch "SMB1 Blocked" "False" -WriteType "Red"
        }
    }

    Context "Checking Scenarios 2" {
        BeforeAll {
            Mock Get-RemoteRegistryValue -ParameterFilter { $GetValue -eq "KeepAliveTime" } -MockWith { return 1800000 }
            $hc = Get-HealthCheckerExchangeServer
            $hc | Export-Clixml $PSScriptRoot\Debug_Scenario2_Results.xml -Depth 6 -Encoding utf8
            $Script:results = Invoke-AnalyzerEngine $hc
        }

        It "TCP Keep Alive Time" {
            SetActiveDisplayGrouping "Frequent Configuration Issues"

            TestObjectMatch "TCP/IP Settings" 1800000 -WriteType "Green"
        }
    }

    Context "Checking Scenario 3 - Physical" {
        BeforeAll {
            $Script:date = Get-Date
            Mock Get-WmiObjectHandler -ParameterFilter { $Class -eq "Win32_ComputerSystem" } `
                -MockWith { return Import-Clixml "$Script:MockDataCollectionRoot\Hardware\Physical_Win32_ComputerSystem1.xml" }
            Mock Get-WmiObjectHandler -ParameterFilter { $Class -eq "Win32_PhysicalMemory" } `
                -MockWith { return Import-Clixml "$Script:MockDataCollectionRoot\Hardware\Physical_Win32_PhysicalMemory.xml" }
            Mock Get-WmiObjectHandler -ParameterFilter { $Class -eq "Win32_Processor" } `
                -MockWith { return Import-Clixml "$Script:MockDataCollectionRoot\Hardware\Physical_Win32_Processor1.xml" }
            $hc = Get-HealthCheckerExchangeServer
            $hc | Export-Clixml $PSScriptRoot\Debug_Scenario3_Physical_Results.xml -Depth 6 -Encoding utf8
            $Script:results = Invoke-AnalyzerEngine $hc
        }

        It "Number of Processors" {
            SetActiveDisplayGrouping "Processor/Hardware Information"
            TestObjectMatch "Number of Processors" 4 -WriteType "Red"
        }

        It "Number of Physical Cores" {
            TestObjectMatch "Number of Physical Cores" 48 -WriteType "Yellow"
        }

        It "Number of Logical Cores" {
            TestObjectMatch "Number of Logical Cores" 96 -WriteType "Yellow"
        }

        It "Hyper-Threading" {
            TestObjectMatch "Hyper-Threading" "True" -WriteType "Red"
        }

        It "NUMA Group Size Optimization" {
            TestObjectMatch "NUMA Group Size Optimization" "Clustered" -WriteType "Red"
        }

        It "Current Processor Speed" {
            TestObjectMatch "Current Processor Speed" 2200 -WriteType "Red"
        }

        It "HighPerformanceSet" {
            TestObjectMatch "HighPerformanceSet" $false -WriteType "Red"
        }
    }
}