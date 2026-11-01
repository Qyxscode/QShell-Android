$path = 'D:\QShell-Android\app\lib\pages\settings\settings_page.dart'
$lines = [IO.File]::ReadAllLines($path, [Text.UTF8Encoding]::new($false))

# replace ASCII placeholders with real Chinese copy
$map = @{
    'WALLPAPER_TITLE'   = "自定义壁纸"
    'WALLPAPER_SUB'     = "玻璃效果需要一个有内容的背景"
    'WALLPAPER_CLEAR'   = "清除"
    'WALLPAPER_PICK'    = "选择"
    'WALLPAPER_CHANGE'  = "更换"
    'WALLPAPER_DIM'     = "压暗"
}
$out = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines) {
    $new = $line
    foreach ($key in $map.Keys) {
        if ($new.Contains($key)) { $new = $new.Replace($key, $map[$key]) }
    }
    $out.Add($new)
}

# add _pickWallpaper method before _openBatterySettings
$method = @'
  /// 从相册/文件中选一张壁纸
  Future<void> _pickWallpaper() async {
    try {
      final result = await FilePicker.pickFile();
      if (!mounted) return;
      if (result == null) return;
      await widget.controller.setWallpaper(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('选择壁纸失败：$e')));
    }
  }

'@

$final = New-Object System.Collections.Generic.List[string]
foreach ($line in $out) {
    if ($line.Contains('Future<void> _openBatterySettings()')) {
        foreach ($m in ($method -split "`r?`n")) { $final.Add($m) }
    }
    $final.Add($line)
}
[IO.File]::WriteAllLines($path, $final, [Text.UTF8Encoding]::new($false))
Write-Output "done total=$($final.Count)"
