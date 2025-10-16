# Windows CIS Compliance Check Script

# Initialize results array
$TestResults = @()

function Test-CISCompliance {
    param (
        [string]$TestName,
        [scriptblock]$TestScript
    )
    
    try {
        $result = & $TestScript
        if ($result) {
            return @{
                Name = $TestName
                Result = "Pass"
                Details = $result
            }
        } else {
            return @{
                Name = $TestName
                Result = "Fail"
                Details = "Test condition not met"
            }
        }
    } catch {
        return @{
            Name = $TestName
            Result = "Error"
            Details = $_.Exception.Message
        }
    }
}

# 1. Check Windows Defender Status
$TestResults += Test-CISCompliance -TestName "Windows Defender Status" -TestScript {
    Get-MpComputerStatus | Select-Object -Property AntivirusEnabled, RealTimeProtectionEnabled
}

# 2. Check Password Policy
$TestResults += Test-CISCompliance -TestName "Password Policy" -TestScript {
    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
}

# 3. Check Windows Firewall Status
$TestResults += Test-CISCompliance -TestName "Windows Firewall" -TestScript {
    Get-NetFirewallProfile | Select-Object Name, Enabled
}

# 4. Check Azure Monitor Agent
$TestResults += Test-CISCompliance -TestName "Azure Monitor Agent" -TestScript {
    Get-Service -Name "AzureMonitorAgent" -ErrorAction SilentlyContinue
}

# 5. Check Windows Updates
$TestResults += Test-CISCompliance -TestName "Windows Updates" -TestScript {
    Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
}

# Generate JUnit XML report
$xmlWriter = New-Object System.XMl.XmlTextWriter("test-results.xml", $null)
$xmlWriter.Formatting = "Indented"
$xmlWriter.WriteStartDocument()

$xmlWriter.WriteStartElement("testsuites")
$xmlWriter.WriteStartElement("testsuite")
$xmlWriter.WriteAttributeString("name", "Windows CIS Compliance")
$xmlWriter.WriteAttributeString("tests", $TestResults.Count)

foreach ($test in $TestResults) {
    $xmlWriter.WriteStartElement("testcase")
    $xmlWriter.WriteAttributeString("classname", "CISBenchmark")
    $xmlWriter.WriteAttributeString("name", $test.Name)
    
    if ($test.Result -ne "Pass") {
        $xmlWriter.WriteStartElement("failure")
        $xmlWriter.WriteAttributeString("message", $test.Details)
        $xmlWriter.WriteEndElement()
    }
    
    $xmlWriter.WriteEndElement()
}

$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndElement()
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()
