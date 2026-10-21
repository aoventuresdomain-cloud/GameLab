# Sets the primary display's resolution on a CI Windows runner, so a game window
# of that size fits on the screen (KIT-08 screenshots). Windows keeps a window no
# larger than the screen, so a 1920x1080 window needs a 1920x1080 display.
#   pwsh tools/ci/set_display_resolution.ps1 -Width 1920 -Height 1080
param(
  [Parameter(Mandatory)][int]$Width,
  [Parameter(Mandatory)][int]$Height
)
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DisplayMode {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
    public int dmFields;
    public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
    public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
    public int dmDisplayFlags; public int dmDisplayFrequency;
    public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
    public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
  }
  [DllImport("user32.dll", CharSet = CharSet.Ansi)]
  public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE mode);
  [DllImport("user32.dll", CharSet = CharSet.Ansi)]
  public static extern int ChangeDisplaySettings(ref DEVMODE mode, int flags);
  public static DEVMODE Current() {
    DEVMODE mode = new DEVMODE();
    mode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
    if (!EnumDisplaySettings(null, -1, ref mode)) { throw new Exception("EnumDisplaySettings failed"); }
    return mode;
  }
}
'@

$mode = [DisplayMode]::Current()
Write-Output "Display before: $($mode.dmPelsWidth)x$($mode.dmPelsHeight)"
$mode.dmPelsWidth = $Width
$mode.dmPelsHeight = $Height
$mode.dmFields = 0x80000 -bor 0x100000   # DM_PELSWIDTH | DM_PELSHEIGHT
# 0 = change for this session only; the runner is thrown away afterwards.
$result = [DisplayMode]::ChangeDisplaySettings([ref]$mode, 0)
$after = [DisplayMode]::Current()
Write-Output "Display after:  $($after.dmPelsWidth)x$($after.dmPelsHeight) (ChangeDisplaySettings returned $result)"
if ($after.dmPelsWidth -ne $Width -or $after.dmPelsHeight -ne $Height) {
  Write-Output "::error::could not set the display to ${Width}x${Height}"
  exit 1
}
