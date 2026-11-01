$path = 'D:\QShell-Android\app\lib\pages\settings\settings_page.dart'
$lines = [IO.File]::ReadAllLines($path, [Text.UTF8Encoding]::new($false))

$block = @'
                        // wallpaper: glass needs something behind it to show through
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceCardAlt,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.wallpaper_rounded,
                                      size: 18, color: tokens.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'WALLPAPER_TITLE',
                                          style: text.bodyMedium?.copyWith(
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'WALLPAPER_SUB',
                                          style: text.labelSmall?.copyWith(
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.controller.wallpaper != null)
                                    TextButton(
                                      onPressed: () {
                                        widget.controller.setWallpaper(null);
                                      },
                                      child: const Text('WALLPAPER_CLEAR'),
                                    ),
                                  TextButton(
                                    onPressed: _pickWallpaper,
                                    child: Text(
                                      widget.controller.wallpaper == null
                                          ? 'WALLPAPER_PICK'
                                          : 'WALLPAPER_CHANGE',
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.controller.wallpaper != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'WALLPAPER_DIM',
                                      style: text.labelSmall?.copyWith(
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: widget.controller.wallpaperDim,
                                        min: 0,
                                        max: 0.8,
                                        divisions: 16,
                                        onChanged: (value) {
                                          widget.controller
                                              .setWallpaperDim(value);
                                        },
                                      ),
                                    ),
                                    Text(
                                      '${(widget.controller.wallpaperDim * 100).round()}%',
                                      style: text.labelSmall?.copyWith(
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
'@

$out = New-Object System.Collections.Generic.List[string]
$inserted = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if (-not $inserted -and $line.Contains('Icons.layers_rounded')) {
        # walk forward to the closing SizedBox(height: 20),
        $j = $i
        while ($j -lt $lines.Length -and -not $lines[$j].Contains('height: 20') -and $lines[$j].Trim() -ne 'const SizedBox(height: 20),') {
            $j++
        }
        for ($k = $i; $k -lt $j; $k++) { $out.Add($lines[$k]) }
        foreach ($b in ($block -split "`r?`n")) { $out.Add($b) }
        $i = $j - 1
        $inserted = $true
        continue
    }
    $out.Add($line)
}
[IO.File]::WriteAllLines($path, $out, [Text.UTF8Encoding]::new($false))
Write-Output "inserted=$inserted total=$($out.Count)"
