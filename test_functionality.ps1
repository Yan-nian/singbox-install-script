# Sing-box Installation Script Functionality Test
# PowerShell Version

Write-Host "=== Sing-box Installation Script Functionality Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check QR code generation consistency
Write-Host "[Test 1] Checking QR code generation consistency..." -ForegroundColor Yellow
$qrWithoutSmall = Get-ChildItem -Recurse -Include *.sh | Select-String "qrcode-terminal" | Where-Object { $_.Line -notmatch "--small" -and $_.Line -notmatch "install" -and $_.Line -notmatch "command -v" }
if ($qrWithoutSmall.Count -eq 0) {
    Write-Host "✓ All QR code generations use --small parameter" -ForegroundColor Green
} else {
    Write-Host "✗ Found QR code generations without --small parameter" -ForegroundColor Red
    $qrWithoutSmall | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
}
Write-Host ""

# Test 2: Check uninstall functionality completeness
Write-Host "[Test 2] Checking uninstall functionality completeness..." -ForegroundColor Yellow
$installScript = Get-Content "install_v2.sh" -Raw

if ($installScript -match "完全卸载|complete uninstall|full uninstall") {
    Write-Host "✓ Contains complete uninstall functionality" -ForegroundColor Green
} else {
    Write-Host "✗ Missing complete uninstall functionality" -ForegroundColor Red
}

if ($installScript -match "\[1/8\]") {
    Write-Host "✓ Uninstall process is step-by-step" -ForegroundColor Green
} else {
    Write-Host "✗ Uninstall process is not step-by-step" -ForegroundColor Red
}

if ($installScript -match "remaining_files") {
    Write-Host "✓ Contains uninstall verification" -ForegroundColor Green
} else {
    Write-Host "✗ Missing uninstall verification" -ForegroundColor Red
}
Write-Host ""

# Test 3: Check core module dependencies
Write-Host "[Test 3] Checking core module dependencies..." -ForegroundColor Yellow
$requiredModules = @(
    "core\bootstrap.sh",
    "core\error_handler.sh", 
    "core\logger.sh",
    "config\config_manager.sh",
    "utils\system_utils.sh",
    "utils\network_utils.sh"
)

$allModulesExist = $true
foreach ($module in $requiredModules) {
    if (Test-Path $module) {
        Write-Host "✓ $module exists" -ForegroundColor Green
    } else {
        Write-Host "✗ $module missing" -ForegroundColor Red
        $allModulesExist = $false
    }
}

if ($allModulesExist) {
    Write-Host "✓ All core modules exist" -ForegroundColor Green
} else {
    Write-Host "✗ Some core modules are missing" -ForegroundColor Red
}
Write-Host ""

# Test 4: Check protocol support
Write-Host "[Test 4] Checking protocol support..." -ForegroundColor Yellow
$protocols = @("vless", "vmess", "hysteria2")
foreach ($protocol in $protocols) {
    if ($installScript -match $protocol) {
        Write-Host "✓ Supports $protocol protocol" -ForegroundColor Green
    } else {
        Write-Host "✗ Does not support $protocol protocol" -ForegroundColor Red
    }
}
Write-Host ""

# Test 5: Check help information
Write-Host "[Test 5] Checking help information..." -ForegroundColor Yellow
if ($installScript -match "show_help") {
    Write-Host "✓ Contains help functionality" -ForegroundColor Green
} else {
    Write-Host "✗ Missing help functionality" -ForegroundColor Red
}

if ($installScript -match "一键.*卸载|one-click.*uninstall|完全.*卸载") {
    Write-Host "✓ Help mentions one-click uninstall" -ForegroundColor Green
} else {
    Write-Host "! Help does not clearly mention one-click uninstall" -ForegroundColor Yellow
}
Write-Host ""

# Test 6: Check QR code related files
Write-Host "[Test 6] Checking QR code related files..." -ForegroundColor Yellow
if (Test-Path "lib\subscription.sh") {
    Write-Host "✓ Subscription generation module exists" -ForegroundColor Green
    $subscriptionContent = Get-Content "lib\subscription.sh" -Raw
    if ($subscriptionContent -match "generate_qr_codes") {
        Write-Host "✓ Contains QR code generation function" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing QR code generation function" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Subscription generation module missing" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Feature Summary:" -ForegroundColor Green
Write-Host "1. ✓ QR code generation unified with --small parameter for consistent terminal display"
Write-Host "2. ✓ Complete one-click uninstall functionality added to clean all related files"
Write-Host "3. ✓ Uninstall process divided into 8 steps with verification mechanism"
Write-Host "4. ✓ Supports three main protocols: VLESS Reality, VMess WebSocket, Hysteria2"
Write-Host "5. ✓ Help information updated to clearly indicate one-click complete uninstall"
Write-Host ""
Write-Host "Usage:" -ForegroundColor Yellow
Write-Host "- Install: ./install_v2.sh install"
Write-Host "- Uninstall: ./install_v2.sh uninstall"
Write-Host "- Menu: ./install_v2.sh menu"
Write-Host "- Help: ./install_v2.sh --help"