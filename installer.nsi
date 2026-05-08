; GroupLancing Browser - Windows Installer
; Professional NSIS Script

!include "MUI2.nsh"
!include "x64.nsh"

; Settings
Name "GroupLancing Browser"
OutFile "GroupLancing-Browser-Setup.exe"
InstallDir "$PROGRAMFILES\GroupLancing"
RequestExecutionLevel admin

; Variables
Var StartMenuFolder

; UI Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU "Application" $StartMenuFolder
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

; Installation
Section "Install GroupLancing Browser"
  SetOutPath "$INSTDIR"
  
  ; Copy all files
  File /r "bin\*.*"
  File /r "scripts\*.*"
  File /r "docs\*.*"
  
  ; Create shortcuts
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
  
  CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
  CreateShortcut "$SMPROGRAMS\$StartMenuFolder\GroupLancing Browser.lnk" \
    "$INSTDIR\scripts\launch.bat" \
    "" \
    "$INSTDIR\bin\Firefox\firefox.exe" \
    0
  
  CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk" \
    "$INSTDIR\Uninstall.exe"
  
  !insertmacro MUI_STARTMENU_WRITE_END
  
  ; Desktop shortcut
  CreateShortcut "$DESKTOP\GroupLancing Browser.lnk" \
    "$INSTDIR\scripts\launch.bat"
  
  ; Uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  
  ; Registry
  WriteRegStr HKCU "Software\GroupLancing" "InstallPath" "$INSTDIR"
  WriteRegStr HKCU "Software\GroupLancing" "Version" "1.0"
SectionEnd

; Uninstall
Section "Uninstall"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\GroupLancing"
  Delete "$DESKTOP\GroupLancing Browser.lnk"
  DeleteRegKey HKCU "Software\GroupLancing"
SectionEnd

; Uninstaller executable
Section "Un.Install"
  SetAutoClose true
SectionEnd
