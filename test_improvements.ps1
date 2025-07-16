# Code Quality Improvement Test Script (PowerShell Version)
# Version: v2.4.3
# Purpose: Test new error handling, logging, validation and config management features

# Set error handling
$ErrorActionPreference = "Stop"

# Color definitions
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
    White = "White"
}

# Test counters
$script:TestCount = 0
$script:PassCount = 0
$script:FailCount = 0

# Test result recording function
function Test-Result {
    param(
        [string]$TestName,
        [string]$Result,
        [string]$Message
    )
    
    $script:TestCount++
    
    if ($Result -eq "PASS") {
        Write-Host "[PASS] $TestName`: $Message" -ForegroundColor $Colors.Green
        $script:PassCount++
    } else {
        Write-Host "[FAIL] $TestName`: $Message" -ForegroundColor $Colors.Red
        $script:FailCount++
    }
}

# Test error handler module
function Test-ErrorHandler {
    Write-Host "`n=== Testing Error Handler Module ===" -ForegroundColor $Colors.Cyan
    
    $libDir = Join-Path $PSScriptRoot "lib"
    $errorHandlerPath = Join-Path $libDir "error_handler.sh"
    
    # Test module file exists
    if (Test-Path $errorHandlerPath) {
        Test-Result "Error Handler File" "PASS" "Module file exists: $errorHandlerPath"
        
        # Check file content
        $content = Get-Content $errorHandlerPath -Raw
        
        # Check error code definitions
        if ($content -match "ERROR_CODES\[") {
            Test-Result "Error Code Definition" "PASS" "Found error code array definition"
        } else {
            Test-Result "Error Code Definition" "FAIL" "Error code array definition not found"
        }
        
        # Check key functions
        $functions = @("handle_error", "handle_warning", "handle_success", "get_error_message")
        foreach ($func in $functions) {
            if ($content -match "$func\s*\(") {
                Test-Result "Error Function $func" "PASS" "Found $func function definition"
            } else {
                Test-Result "Error Function $func" "FAIL" "$func function definition not found"
            }
        }
        
    } else {
        Test-Result "Error Handler File" "FAIL" "Module file does not exist: $errorHandlerPath"
    }
}

# Test logger module
function Test-Logger {
    Write-Host "`n=== Testing Logger Module ===" -ForegroundColor $Colors.Cyan
    
    $libDir = Join-Path $PSScriptRoot "lib"
    $loggerPath = Join-Path $libDir "logger.sh"
    
    # Test module file exists
    if (Test-Path $loggerPath) {
        Test-Result "Logger File" "PASS" "Module file exists: $loggerPath"
        
        # Check file content
        $content = Get-Content $loggerPath -Raw
        
        # Check log level definitions
        $logLevels = @("DEBUG", "INFO", "WARN", "ERROR", "FATAL")
        $foundLevels = 0
        foreach ($level in $logLevels) {
            if ($content -match $level) {
                $foundLevels++
            }
        }
        
        if ($foundLevels -eq $logLevels.Count) {
            Test-Result "Log Level Definition" "PASS" "Found all log level definitions"
        } else {
            Test-Result "Log Level Definition" "FAIL" "Log level definitions incomplete ($foundLevels/$($logLevels.Count))"
        }
        
        # Check key functions
        $functions = @("init_logger", "log_debug", "log_info", "log_warn", "log_error", "log_fatal")
        foreach ($func in $functions) {
            if ($content -match "$func\s*\(") {
                Test-Result "Log Function $func" "PASS" "Found $func function definition"
            } else {
                Test-Result "Log Function $func" "FAIL" "$func function definition not found"
            }
        }
        
        # Check log file management
        if ($content -match "LOG_FILE" -and $content -match "rotate_log_file") {
            Test-Result "Log File Management" "PASS" "Found log file management features"
        } else {
            Test-Result "Log File Management" "FAIL" "Log file management features incomplete"
        }
        
    } else {
        Test-Result "Logger File" "FAIL" "Module file does not exist: $loggerPath"
    }
}

# Test validator module
function Test-Validator {
    Write-Host "`n=== Testing Validator Module ===" -ForegroundColor $Colors.Cyan
    
    $libDir = Join-Path $PSScriptRoot "lib"
    $validatorPath = Join-Path $libDir "validator.sh"
    
    # Test module file exists
    if (Test-Path $validatorPath) {
        Test-Result "Validator File" "PASS" "Module file exists: $validatorPath"
        
        # Check file content
        $content = Get-Content $validatorPath -Raw
        
        # Check validation functions
        $functions = @(
            "validate_port", "validate_domain", "validate_ipv4", 
            "validate_ipv6", "validate_uuid", "validate_path",
            "sanitize_input", "batch_validate"
        )
        
        foreach ($func in $functions) {
            if ($content -match "$func\s*\(") {
                Test-Result "Validator Function $func" "PASS" "Found $func function definition"
            } else {
                Test-Result "Validator Function $func" "FAIL" "$func function definition not found"
            }
        }
        
        # Check port range validation
        if ($content -match "1024" -and $content -match "65535") {
            Test-Result "Port Range Validation" "PASS" "Found port range validation logic"
        } else {
            Test-Result "Port Range Validation" "FAIL" "Port range validation logic incomplete"
        }
        
        # Check regex patterns
        if ($content -match "UUID_PATTERN" -and $content -match "DOMAIN_PATTERN") {
            Test-Result "Validation Patterns" "PASS" "Found validation pattern definitions"
        } else {
            Test-Result "Validation Patterns" "FAIL" "Validation pattern definitions incomplete"
        }
        
    } else {
        Test-Result "Validator File" "FAIL" "Module file does not exist: $validatorPath"
    }
}

# Test config manager module
function Test-ConfigManager {
    Write-Host "`n=== Testing Config Manager Module ===" -ForegroundColor $Colors.Cyan
    
    $libDir = Join-Path $PSScriptRoot "lib"
    $configPath = Join-Path $libDir "config_manager.sh"
    
    # Test module file exists
    if (Test-Path $configPath) {
        Test-Result "Config Manager File" "PASS" "Module file exists: $configPath"
        
        # Check file content
        $content = Get-Content $configPath -Raw
        
        # Check core functions
        $functions = @(
            "init_config_vars", "load_config", "save_config", 
            "auto_load_config", "get_config_status", "reload_config",
            "load_config_from_cache", "save_config_to_cache"
        )
        
        foreach ($func in $functions) {
            if ($content -match "$func\s*\(") {
                Test-Result "Config Function $func" "PASS" "Found $func function definition"
            } else {
                Test-Result "Config Function $func" "FAIL" "$func function definition not found"
            }
        }
        
        # Check protocol extraction functions
        $extractFunctions = @("extract_vless_config", "extract_vmess_config", "extract_hysteria2_config")
        foreach ($func in $extractFunctions) {
            if ($content -match "$func\s*\(") {
                Test-Result "Extract Function $func" "PASS" "Found $func function definition"
            } else {
                Test-Result "Extract Function $func" "FAIL" "$func function definition not found"
            }
        }
        
        # Check cache mechanism
        if ($content -match "CONFIG_STATE_FILE" -and $content -match "cache") {
            Test-Result "Config Cache Mechanism" "PASS" "Found config cache mechanism"
        } else {
            Test-Result "Config Cache Mechanism" "FAIL" "Config cache mechanism incomplete"
        }
        
        # Check error handling integration
        if ($content -match "handle_error" -and $content -match "log_") {
            Test-Result "Error Handling Integration" "PASS" "Config manager integrated with error handling and logging"
        } else {
            Test-Result "Error Handling Integration" "FAIL" "Config manager not properly integrated with error handling and logging"
        }
        
    } else {
        Test-Result "Config Manager File" "FAIL" "Module file does not exist: $configPath"
    }
}

# Test main script integration
function Test-MainScriptIntegration {
    Write-Host "`n=== Testing Main Script Integration ===" -ForegroundColor $Colors.Cyan
    
    $mainScript = Join-Path $PSScriptRoot "singbox-install.sh"
    
    if (Test-Path $mainScript) {
        Test-Result "Main Script File" "PASS" "Main script file exists: $mainScript"
        
        # Check file content
        $content = Get-Content $mainScript -Raw
        
        # Check new module loading
        $newModules = @("error_handler.sh", "logger.sh", "validator.sh")
        foreach ($module in $newModules) {
            if ($content -match $module) {
                Test-Result "Module Integration $module" "PASS" "Main script includes $module"
            } else {
                Test-Result "Module Integration $module" "FAIL" "Main script does not include $module"
            }
        }
        
        # Check auto config loading
        if ($content -match "auto_load_config") {
            Test-Result "Auto Config Loading" "PASS" "Main script includes auto config loading"
        } else {
            Test-Result "Auto Config Loading" "FAIL" "Main script missing auto config loading"
        }
        
        # Check logging integration
        if ($content -match "log_info") {
            Test-Result "Logging Integration" "PASS" "Main script includes logging functionality"
        } else {
            Test-Result "Logging Integration" "FAIL" "Main script missing logging functionality"
        }
        
        # Check enhanced version identifier
        if ($content -match "Enhanced" -or $content -match "增强") {
            Test-Result "Version Identifier" "PASS" "Main script includes enhanced version identifier"
        } else {
            Test-Result "Version Identifier" "FAIL" "Main script missing enhanced version identifier"
        }
        
    } else {
        Test-Result "Main Script File" "FAIL" "Main script file does not exist: $mainScript"
    }
}

# Test documentation and plans
function Test-Documentation {
    Write-Host "`n=== Testing Documentation and Plans ===" -ForegroundColor $Colors.Cyan
    
    # Check implementation plan document
    $planDoc = Join-Path $PSScriptRoot "implementation-plan-v2.4.3.md"
    if (Test-Path $planDoc) {
        Test-Result "Implementation Plan Doc" "PASS" "Implementation plan document exists: $planDoc"
    } else {
        Test-Result "Implementation Plan Doc" "FAIL" "Implementation plan document does not exist: $planDoc"
    }
    
    # Check improvement suggestions document
    $suggestionDoc = Join-Path $PSScriptRoot "improvement-suggestions-v2.4.3.md"
    if (Test-Path $suggestionDoc) {
        Test-Result "Improvement Suggestions Doc" "PASS" "Improvement suggestions document exists: $suggestionDoc"
    } else {
        Test-Result "Improvement Suggestions Doc" "FAIL" "Improvement suggestions document does not exist: $suggestionDoc"
    }
}

# Main test function
function Main {
    Write-Host "Code Quality Improvement Test Started" -ForegroundColor $Colors.Blue
    Write-Host "Test Time: $(Get-Date)" -ForegroundColor $Colors.Blue
    Write-Host "Test Version: v2.4.3" -ForegroundColor $Colors.Blue
    Write-Host "Test Environment: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor $Colors.Blue
    
    # Run all tests
    Test-ErrorHandler
    Test-Logger
    Test-Validator
    Test-ConfigManager
    Test-MainScriptIntegration
    Test-Documentation
    
    # Display test results
    Write-Host "`n=== Test Results Summary ===" -ForegroundColor $Colors.Blue
    Write-Host "Total Tests: $script:TestCount"
    Write-Host "Passed: $script:PassCount" -ForegroundColor $Colors.Green
    Write-Host "Failed: $script:FailCount" -ForegroundColor $Colors.Red
    
    $successRate = [math]::Round(($script:PassCount / $script:TestCount) * 100, 2)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { $Colors.Green } elseif ($successRate -ge 70) { $Colors.Yellow } else { $Colors.Red })
    
    if ($script:FailCount -eq 0) {
        Write-Host "`nAll tests passed! Code quality improvement implementation successful." -ForegroundColor $Colors.Green
        exit 0
    } else {
        Write-Host "`n$script:FailCount tests failed. Please check the related modules." -ForegroundColor $Colors.Red
        
        # Provide improvement suggestions
        Write-Host "`nImprovement Suggestions:" -ForegroundColor $Colors.Yellow
        Write-Host "1. Check if failed module files exist" -ForegroundColor $Colors.Yellow
        Write-Host "2. Verify function definitions are correct" -ForegroundColor $Colors.Yellow
        Write-Host "3. Ensure module dependencies are correct" -ForegroundColor $Colors.Yellow
        
        exit 1
    }
}

# Run tests
Main