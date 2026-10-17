# P150C Release 编译并打包脚本（Windows / Qt 6.12 MinGW 64-bit）
# 用法（在项目根目录执行）：
#   powershell -ExecutionPolicy Bypass -File .\package-release.ps1
# 可选参数：
#   -QtDir        Qt 安装目录（默认 C:\Qt\6.12.0\mingw_64）
#   -MingwDir     MinGW 工具链目录（默认 C:\Qt\Tools\mingw1310_64）
#   -SkipTrim     传此开关则不裁剪未使用的 QML 样式和翻译
param(
    [string]$QtDir   = "C:\Qt\6.12.0\mingw_64",
    [string]$MingwDir = "C:\Qt\Tools\mingw1310_64",
    [string]$CMakeDir = "C:\Qt\Tools\CMake_64",
    [string]$Version = "1.0",
    [switch]$SkipTrim
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$BuildDir   = Join-Path $ProjectDir "build\Desktop_Qt_6_12_0_MinGW_64_bit_Release"
$DistRoot   = Join-Path $ProjectDir "build\release-package"
$PkgDir     = Join-Path $DistRoot "P150C"

$env:PATH = "$MingwDir\bin;$CMakeDir\bin;$QtDir\bin;$env:PATH"
$cmake = Join-Path $CMakeDir "bin\cmake.exe"
$windeployqt = Join-Path $QtDir "bin\windeployqt.exe"

Write-Host "==> [1/5] 配置 Release 构建目录..." -ForegroundColor Cyan
& $cmake -S $ProjectDir -B $BuildDir -G "MinGW Makefiles" `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_PREFIX_PATH="$($QtDir -replace '\\','/')" `
    -DCMAKE_CXX_COMPILER="$($MingwDir -replace '\\','/')/bin/g++.exe"

Write-Host "==> [2/5] 编译..." -ForegroundColor Cyan
& $cmake --build $BuildDir --parallel

$exe = Join-Path $BuildDir "P150C.exe"
if (-not (Test-Path $exe)) { throw "未找到编译产物: $exe" }

Write-Host "==> [3/5] 准备发布目录..." -ForegroundColor Cyan
if (Test-Path $PkgDir) { Remove-Item $PkgDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $PkgDir | Out-Null
Copy-Item $exe $PkgDir -Force

Write-Host "==> [4/5] windeployqt 收集依赖..." -ForegroundColor Cyan
& $windeployqt --release --compiler-runtime --qmldir $ProjectDir (Join-Path $PkgDir "P150C.exe") | Out-Null

if (-not $SkipTrim) {
    Write-Host "==> [5/5] 裁剪未使用的 QML 样式（仅保留 Basic + Fusion）与非中文翻译..." -ForegroundColor Cyan
    # 本项目 main.cpp 固定使用 Fusion 样式；Fusion 对未重写控件回落到 Basic，二者必须保留。
    foreach ($s in @("FluentWinUI3", "Imagine", "Material", "Universal", "Windows", "Native")) {
        $p = Join-Path $PkgDir "qml\QtQuick\Controls\$s"
        if (Test-Path $p) { Remove-Item $p -Recurse -Force }
    }
    foreach ($d in @("FluentWinUI3", "Imagine", "Material", "Universal", "Windows")) {
        Get-ChildItem $PkgDir -File -Filter "*Controls2$d*.dll" | Remove-Item -Force
    }
    $nativeStyle = Join-Path $PkgDir "Qt6QuickNativeStyle.dll"
    if (Test-Path $nativeStyle) { Remove-Item $nativeStyle -Force }
    $trDir = Join-Path $PkgDir "translations"
    if (Test-Path $trDir) {
        Get-ChildItem $trDir -File | Where-Object { $_.Name -notmatch "zh_CN|zh_TW" } | Remove-Item -Force
    }

    # 以下文件已经过干净环境（PATH 不含 Qt）启动验证，确认本项目不需要：
    # opengl32sw    Qt6 默认走 D3D11，软件 OpenGL 兜底用不到（目标机需 Win10+）
    # D3Dcompiler_47 Win10 1607+ 系统自带于 System32
    # qmltooling    QML 调试器插件，发布版不需要
    # imageformats  仅使用 PNG（QtGui 内置），JPEG/GIF/ICO 插件用不到
    # tls / networkinformation  程序不发起网络连接
    # iconengines + Qt6Svg      不使用 SVG 图标
    # generic       触摸等输入插件，桌面程序不需要
    # *.qmltypes    Qt Creator 代码提示元数据，运行时不需要
    # QuickEffects / Quick3DUtils / QuickShapes  本项目与 Basic/Fusion 样式均未使用
    # 注意：Qt6QmlWorkerScript.dll 不能删——Qt6QmlMeta.dll（被 Qt6Quick 引用）静态依赖它
    Get-ChildItem $PkgDir -File | Where-Object { $_.Name -in @(
        "opengl32sw.dll", "D3Dcompiler_47.dll", "Qt6Svg.dll",
        "Qt6QuickEffects.dll", "Qt6Quick3DUtils.dll", "Qt6QuickShapes.dll") } | Remove-Item -Force
    foreach ($dir in @("qmltooling", "imageformats", "tls", "networkinformation", "iconengines", "generic")) {
        $p = Join-Path $PkgDir $dir
        if (Test-Path $p) { Remove-Item $p -Recurse -Force }
    }
    foreach ($dir in @("qml\QtQuick\Effects", "qml\QtQuick\Shapes", "qml\QtQml\WorkerScript", "qml\QtQuick\NativeStyle")) {
        $p = Join-Path $PkgDir $dir
        if (Test-Path $p) { Remove-Item $p -Recurse -Force }
    }
    Get-ChildItem (Join-Path $PkgDir "qml") -Recurse -File -Filter "*.qmltypes" -ErrorAction SilentlyContinue | Remove-Item -Force
} else {
    Write-Host "==> [5/5] 跳过裁剪" -ForegroundColor Cyan
}

$sizeMB = "{0:N1}" -f ((Get-ChildItem $PkgDir -Recurse | Measure-Object Length -Sum).Sum / 1MB)

$ZipPath = Join-Path $DistRoot "P150C_v$($Version)_win64.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path $PkgDir -DestinationPath $ZipPath -CompressionLevel Optimal
$zipMB = "{0:N1}" -f ((Get-Item $ZipPath).Length / 1MB)

Write-Host ""
Write-Host "打包完成: $PkgDir ($sizeMB MB)" -ForegroundColor Green
Write-Host "压缩包:   $ZipPath ($zipMB MB)" -ForegroundColor Green
Write-Host "将整个 P150C 文件夹（或 zip 解压后）拷贝到目标电脑即可运行（无需安装 Qt）。" -ForegroundColor Green
