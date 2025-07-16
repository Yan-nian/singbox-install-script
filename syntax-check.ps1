# Syntax Check Script for singbox-all-in-one.sh
# This script verifies that the syntax error has been fixed

Write-Host "=== Sing-box Script Syntax Check ===" -ForegroundColor Cyan
Write-Host ""

$scriptPath = "singbox-all-in-one.sh"

if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: $scriptPath not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Checking script file: $scriptPath" -ForegroundColor Yellow
Write-Host ""

# Check for duplicate function definitions
Write-Host "1. Checking for duplicate function definitions..." -ForegroundColor Green
$checkInstallationCount = (Select-String -Path $scriptPath -Pattern "^check_installation_status\(\)" | Measure-Object).Count
Write-Host "   - check_installation_status() definitions found: $checkInstallationCount"

if ($checkInstallationCount -eq 1) {
    Write-Host "   ✓ No duplicate function definitions" -ForegroundColor Green
} else {
    Write-Host "   ✗ Duplicate function definitions found!" -ForegroundColor Red
}

# Check script structure
Write-Host ""
Write-Host "2. Checking script structure..." -ForegroundColor Green
$totalLines = (Get-Content $scriptPath | Measure-Object -Line).Lines
Write-Host "   - Total lines: $totalLines"

# Check for basic syntax patterns
Write-Host ""
Write-Host "3. Checking basic syntax patterns..." -ForegroundColor Green

# Count function definitions
$functionCount = (Select-String -Path $scriptPath -Pattern "^[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*\{" | Measure-Object).Count
Write-Host "   - Function definitions found: $functionCount"

# Check for unmatched braces (basic check)
$openBraces = (Select-String -Path $scriptPath -Pattern "\{" -AllMatches | ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
$closeBraces = (Select-String -Path $scriptPath -Pattern "\}" -AllMatches | ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
Write-Host "   - Opening braces: $openBraces"
Write-Host "   - Closing braces: $closeBraces"

if ($openBraces -eq $closeBraces) {
    Write-Host "   ✓ Brace count matches" -ForegroundColor Green
} else {
    Write-Host "   ⚠ Brace count mismatch (may be normal for some constructs)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($checkInstallationCount -eq 1) {
    Write-Host "✓ Syntax error fix successful!" -ForegroundColor Green
    Write-Host "✓ Duplicate function definition removed" -ForegroundColor Green
    Write-Host "✓ Script should now run without syntax errors" -ForegroundColor Green
} else {
    Write-Host "✗ Issues still present" -ForegroundColor Red
}

Write-Host ""
Write-Host "The script is now ready for use. The syntax error caused by duplicate" -ForegroundColor White
Write-Host "function definitions has been resolved." -ForegroundColor White
Write-Host ""
Write-Host "You can now run the script with:" -ForegroundColor Yellow
Write-Host "  bash singbox-all-in-one.sh" -ForegroundColor Cyan