Unicode True
!addplugindir /x86-unicode "files/Plugins/x86-unicode"
!include WinVer.nsh		; ${AtLeastWin7}
!include x64.nsh		; ${RunningX64}
!include FileFunc.nsh	; ${GetOptions}
!include StrFunc.nsh	; ${StrRep}
${StrRep}

; -------------------------- Defines -------------------------------------
!define VERSION "3.0.1"
!system  "python build.py"
!include "build.nsh"
!ifndef BUILD
	!define BUILD "0"
!endif
!ifndef PRODUCT_VERSION
	!define PRODUCT_VERSION "${VERSION}"
!endif
!ifndef OUTDIR
	!define OUTDIR "..\build"
!endif

!define APPNAME "TorrServer"
!define PRODUCT_PUBLISHER "Noperkot"
!define COPYRIGHT "${AUTHORS} © 2024"
!define REG_UNINST_SUBKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
!define REG_RUN_SUBKEY "Software\Microsoft\Windows\CurrentVersion\Run"
!define ICONSDIR "files\icons" 
!define UNINSTALLICON "uninst.ico"
!define TS32EXE "TorrServer-windows-386.exe"
!define TS64EXE "TorrServer-windows-amd64.exe"
!define ONLINE_INSTALLER "TorrServer_Setup.exe"
!define UNINSTALLER "Uninstall.exe"
!define LINKSDIR "$INSTDIR\Links"
!define SHORTCUTSDIR "$INSTDIR\Shortcuts"
!define AUTOUPDATE_TASK "${APPNAME}Updater"

; -------------------------- Variables -----------------------------------
Var TempDir
Var AbortMessage
Var TS_Installed
Var	TS_toInstall
Var TSselector_DL
Var	TSexe
Var RunOnComplete

; -------------------------- Main settings -------------------------------
Name "${APPNAME}"
Caption "${CAPTION}"
UninstallCaption "${APPNAME} Uninstaller"
InstallDir "$APPDATA\${APPNAME}"
InstallDirRegKey HKCU "Software\${APPNAME}" ""
OutFile "${OUTDIR}/${INSTALLER}"
; SetCompressor lzma ; zlib bzip2 lzma off	; lzma лучше пакует(~10%), но VirusTotal благосклонней относится к дефолтному zlib???
; ManifestSupportedOS none					;
ManifestDPIAware true
RequestExecutionLevel highest				; user, admin
AllowRootDirInstall true
BrandingText " "							; убираем из окна инсталлятора строку строку "Nullsoft Install System vX.XX"
SpaceTexts none 							; убираем требуемое место на диске
; ShowInstDetails show
; ShowInstDetails nevershow
; ShowUnInstDetails show

; --------------------------- MUI settings -------------------------------
!include MUI2.nsh
!define MUI_ICON "${ICONSDIR}\${INSTALLICON}"
!define MUI_UNICON "${ICONSDIR}\${UNINSTALLICON}"
; !define MUI_ABORTWARNING
; !define MUI_FINISHPAGE_NOAUTOCLOSE
;
!define MUI_PAGE_CUSTOMFUNCTION_PRE WelcomePagePre		; проверка ключа /SkipWelcome
!insertmacro MUI_PAGE_WELCOME							; страница приветствия
!insertmacro Preinstall									; получаем список версий ТС
Page Custom OptionsPageCreate OptionsPageLeave			; страница выбора верси и пути установки
!insertmacro MUI_PAGE_INSTFILES							; собственно сама установка
!define MUI_FINISHPAGE_RUN								; галка запуска на финишной странице
!define MUI_PAGE_CUSTOMFUNCTION_SHOW FinishPageShow		; генерируем дополнительные чекбоксы
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE FinishPageLeave	; обрабатываем чекбоксы после нажатия кнопки "Готово"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT					; без поддержки ребута, чуть снижает вес(~300байт)
!insertmacro MUI_PAGE_FINISH							; финишная страница с чекбоксами

; ---------------------------- MUI uninstall -----------------------------
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; --------------- Set languages (first is default language) --------------
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Russian"

; -------------------------- Version Information -------------------------
VIProductVersion "${VERSION}.0"
VIFileVersion    "${VERSION}.${BUILD}"
VIAddVersionKey  /LANG=${LANG_ENGLISH} "FileVersion" "${VERSION}.${BUILD}"
VIAddVersionKey  /LANG=${LANG_ENGLISH} "FileDescription" "${CAPTION}"
VIAddVersionKey  /LANG=${LANG_ENGLISH} "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey  /LANG=${LANG_ENGLISH} "ProductName" "${APPNAME} Installer"
VIAddVersionKey  /LANG=${LANG_ENGLISH} "LegalCopyright" "${COPYRIGHT}"
VIAddVersionKey  /LANG=${LANG_ENGLISH} "NSIS" "${NSIS_VERSION} (${OS})"
;
; VIAddVersionKey  /LANG=${LANG_ENGLISH} "OriginalFilename" "${INSTALLER}" ;
; VIAddVersionKey  /LANG=${LANG_ENGLISH} "CompanyName" "${PRODUCT_PUBLISHER}"
; VIAddVersionKey  /LANG=${LANG_ENGLISH} "LegalTrademarks" ""
; VIAddVersionKey  /LANG=${LANG_ENGLISH} "InternalName" "TorrServer_Setup"
; VIAddVersionKey  /LANG=${LANG_ENGLISH} "Comments" "TorrServer is a program that allows users to view torrents online without the need for preliminary file downloading."
; ------------------------------------------------------------------------

!macro CloseTS hwnd			; Гасим торрсервер запущенный через tsl.exe
	FindWindow ${hwnd} "TorrServerLauncher"
	${IfNot} ${hwnd} == 0
		SendMessage ${hwnd} ${WM_DESTROY} 0 0
		Sleep 100
	${EndIf}
!macroend

!macro CheckMutex ; проверка уже запущенного экземпляра установщика
	Push $0
	System::Call 'kernel32::CreateMutex(i 0, i 0, t "TorrServerSetup") i .r1 ?e'
	Pop $0
	${IfNot} $0 == 0
		MessageBox MB_OK|MB_ICONSTOP "$(_ALREADY_RUNNING_)" /SD IDOK
		Quit
	${EndIf}
	Pop $0
!macroend

!macro WriteLn s
	FileWriteUTF16LE $0 `${s}$\r$\n`
!macroend

!define WriteLn "!insertmacro WriteLn"

!macro AutoupdateTaskCreate
	Push $0
	Push $1
	${Do} ; Генерируем случайное имя xml файла в темпе. VT не нравится(CRITICAL) ".tmp"(расширение $PLUGINSDIR) в пути .xml файла. Имя сгенерированное GetTempFileName ему тоже не нравится.
		Crypto::RNG
		Pop $1							; $1 now contains 100 bytes of random data in hex format
		StrCpy $1 "$1" 32				; берем первые 32 символа
		StrCpy $1 "$TEMP\$1.XML"
		; StrCpy $1 "$PLUGINSDIR\$1.XML" ; !!! VT (CRITICAL) !!!
		${IfNot} ${FileExists} "$1"
			${Break}
		${EndIf}
	${Loop}
	ClearErrors
	FileOpen $0 $1 w
	${IfNot} ${Errors}
		;write UTF-16LE BOM
		FileWriteByte $0 "255"
		FileWriteByte $0 "254"
		;
 		${WriteLn} '<?xml version="1.0" encoding="UTF-16"?>'
		${WriteLn} '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'
		${WriteLn} '  <RegistrationInfo>'
		${WriteLn} '    <Description>$(_TASK_DESCRIPTION_)</Description>'
		${WriteLn} '  </RegistrationInfo>'
		${WriteLn} '  <Triggers>'
		${WriteLn} '    <CalendarTrigger>'
		${WriteLn} '      <StartBoundary>2000-01-01T06:00:00</StartBoundary>'
		${WriteLn} '      <ScheduleByDay>'
		${WriteLn} '        <DaysInterval>1</DaysInterval>'
		${WriteLn} '      </ScheduleByDay>'
		; ${WriteLn} '      <Repetition>' ; !!!!!!!!!!!!!!!!!!! ежечасная проверка обновлений. в релизе убрать !!!!!!!!!!!!!!!!!!!!!
		; ${WriteLn} '        <Interval>PT1H</Interval>'
		; ${WriteLn} '        <Duration>P1D</Duration>'
		; ${WriteLn} '        <StopAtDurationEnd>false</StopAtDurationEnd>'
		; ${WriteLn} '      </Repetition>'
		${WriteLn} '      <Enabled>true</Enabled>'
		${WriteLn} '    </CalendarTrigger>'
		${WriteLn} '  </Triggers>'
		${WriteLn} '  <Principals>'
		${WriteLn} '    <Principal id="Author">'
		${WriteLn} '      <RunLevel>HighestAvailable</RunLevel>'
		${WriteLn} '    </Principal>'
		${WriteLn} '  </Principals>'
		${WriteLn} '  <Settings>'
		${WriteLn} '    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>'
		${WriteLn} '    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
		${WriteLn} '    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>'
		${WriteLn} '    <AllowHardTerminate>true</AllowHardTerminate>'
		${WriteLn} '    <StartWhenAvailable>true</StartWhenAvailable>'
		${WriteLn} '    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>'
		${WriteLn} '    <IdleSettings>'
		${WriteLn} '      <StopOnIdleEnd>false</StopOnIdleEnd>'
		${WriteLn} '      <RestartOnIdle>false</RestartOnIdle>'
		${WriteLn} '    </IdleSettings>'
		${WriteLn} '    <AllowStartOnDemand>true</AllowStartOnDemand>'
		${WriteLn} '    <Enabled>true</Enabled>'
		${WriteLn} '    <Hidden>false</Hidden>'
		${WriteLn} '    <RunOnlyIfIdle>false</RunOnlyIfIdle>'
		${WriteLn} '    <WakeToRun>false</WakeToRun>'
		${WriteLn} '    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>'
		${WriteLn} '    <Priority>7</Priority>'
		${WriteLn} '  </Settings>'
		${WriteLn} '  <Actions Context="Author">'
		${WriteLn} '    <Exec>'
		${WriteLn} '      <Command>"$INSTDIR\${ONLINE_INSTALLER}"</Command>'
		${WriteLn} '      <Arguments>/S</Arguments>'
		${WriteLn} '    </Exec>'
		${WriteLn} '  </Actions>'
		${WriteLn} '</Task>'
		FileClose $0
		ExecShellWait '' 'schtasks' '/create /tn "${AUTOUPDATE_TASK}" /xml "$1" /f' SW_HIDE
		; ExecDos::exec 'schtasks /create /tn "${AUTOUPDATE_TASK}" /xml "$1" /f' '' ''
		; Pop $0
	${endIf}
	Delete /REBOOTOK $1
	Pop $1
	Pop $0
!macroend

!macro AutoupdateTaskRemove
	ExecShell '' 'schtasks' '/delete /tn "${AUTOUPDATE_TASK}" /f' SW_HIDE
	; ExecDos::exec 'schtasks /delete /tn "${AUTOUPDATE_TASK}" /f' '' ''
	; Pop $0
!macroend

!macro fwRuleCreate exepath result
	; /* плагин nsisFirewallW разрешает только частное подключение, для общего все равно всплывает запрос брандмауэра????? */
	; nsisFirewallW::AddAuthorizedApplication `${exepath}` "${APPNAME}"
	; Pop ${result} ; 0-success

	ExecDos::exec 'netsh advfirewall firewall add rule name="${APPNAME}" dir=in action=allow program="${exepath}" enable=yes profile=public,private' '' ''
	Pop ${result}
!macroend

!macro fwRuleRemove exepath result
	; nsisFirewallW::RemoveAuthorizedApplication `${exepath}`
	; Pop ${result} ; 0-success
	
	UserInfo::GetAccountType
	Pop ${result}
	${If} ${result} == "admin"
		ExecDos::exec 'netsh advfirewall firewall delete rule name=all program="${exepath}"' '' ''
		Pop ${result} ; 0 - правило успешно удалено, 1 - такого правила не было
		${If} ${result} == 1
			StrCpy ${result} 0
		${EndIf}
	${EndIf}
!macroend

Function _abort_
	Pop $0
	DetailPrint "$0"
	DetailPrint "$(_INSTALLATION_FAILED_)"
	SetDetailsView show
	StrCpy $AbortMessage $0
	Abort
FunctionEnd

!macro _abort_ msg
	Push `${msg}`
	Call _abort_
!macroend

!define _abort_ "!insertmacro _abort_"

Function WelcomePagePre
	Push $0
	ClearErrors
	${GetOptions} $CMDLINE "/SkipWelcome" $0	; пропуск страницы WELCOME
	${IfNot} ${Errors}
		Abort
	${EndIf}
	${NSD_SetText} $mui.Button.Next "$(^NextBtn)"	; "Далее" вместо "Установить"
	Pop $0
FunctionEnd

Function OptionsPageCreate
	Push $0
	
	!insertmacro MUI_HEADER_TEXT "$(_CUSTOM_PAGE_TITLE_)" "$(^ComponentsText)"

	Var /GLOBAL SelVer_DLG
	Var /GLOBAL TSupd_L
	Var /GLOBAL InstallOptionsText

    nsDialogs::Create 1018
    Pop $SelVer_DLG
    ${If} $SelVer_DLG == error
		${_abort_} "$(_UNEXPECTED_ERROR_)"
    ${EndIf}

	; фрейм TorrServer
	${NSD_CreateGroupBox} 25% 30u 50% 44u "TorrServer"
	${NSD_CreateDropList} 35% 47u 30% 12u ""
    Pop $TSselector_DL
	EnableWindow $TSselector_DL 0
	nsDialogs::CreateControl STATIC ${WS_CHILD}|${SS_RIGHT}|${SS_CENTERIMAGE} 0 35% 35u 30% 12u "$(_NEW_VERSION_)"
	Pop $TSupd_L
	SetCtlColors $TSupd_L 0x0066CC "transparent"
	nsDialogs::CreateControl STATIC ${WS_CHILD}|${SS_RIGHT}|${WS_VISIBLE}|${WS_DISABLED} 0 35% 60u 30% 12u "$TS_installed"

	; строка сообщений под фреймом
	nsDialogs::CreateControl STATIC ${WS_CHILD}|${SS_CENTER}|${SS_CENTERIMAGE}|${WS_VISIBLE}|${WS_DISABLED} 0 0 80u 100% 12u ""
	Pop $InstallOptionsText

	; выбор пути установки
	${NSD_CreateGroupBox} 0% 105u 100% 35u "$(^DirSubText)"
	Var /GLOBAL InstDir_DR
	${NSD_CreateDirRequest} 5% 119u 70% 12u "$INSTDIR"
	Pop $InstDir_DR
	${NSD_OnChange} $InstDir_DR OnDirChange
	${NSD_CreateBrowseButton} 78% 118u 17% 14u "$(^BrowseBtn)"
	Pop $0
	${NSD_OnClick} $0 OnDirBrowse
	
	${If} ${FileExists} "$INSTDIR\${UNINSTALLER}"						; считаем что TS уже установлен если по этому пути есть файл Uninstall.exe
		EnableWindow $InstDir_DR 0										; гасим строку с путем
		EnableWindow $0 0												; гасим кнопку выбора пути
		${NSD_SetText} $mui.Header.SubText  "$(_REINSTALL_SUBTEXT_)"	; сообщаем что это переустановка
	${EndIf}

	Call fillTSselector
	${NSD_CB_SelectString} $TSselector_DL $TS_toInstall					; выбираем из списка устанавливаемую версию

	; проверяем есть ли обновление
	Var /GLOBAL origNextFont
	SendMessage $mui.Button.Next ${WM_GETFONT} 0 0 $origNextFont		; сохраняем шрифт кнопки "далее"
	${If} $TS_Installed != ""											; TS установлен
		${If} $TS_toInstall == $TS_Installed							; обновлений нет
			${NSD_SetText} $InstallOptionsText "$(_NO_UPDATES_FOUND_)"	; сообщаем об этом в нижней строке
			CreateFont  $0 "Microsoft Sans Serif" "6"					; Уменьшаем шрифт кнопки "далее" чтобы влезло по ширине
			SendMessage $mui.Button.Next ${WM_SETFONT} $0 0				;
			${NSD_SetText} $mui.Button.Next "$(_REINSTALL_)"			; Меняем текст кнопки "далее" на "переустановить"
		${Else}															; есть обновление
			ShowWindow $TSupd_L ${SW_SHOW}
		${EndIf}
	${EndIf}

    nsDialogs::Show
	
	Pop $0
FunctionEnd

Function OnDirBrowse
	Push $0
	${NSD_GetText} $InstDir_DR $0
	nsDialogs::SelectFolderDialog "$(^DirBrowseText)" $0
	Pop $0
	${If} $0 != "error"
		${NSD_SetText} $InstDir_DR $0
	${EndIf}
	Pop $0
FunctionEnd

Function OnDirChange
	Push $0
	Push $1
	${NSD_GetText} $InstDir_DR $0
	StrCpy $1 $0 2 1	; ":\"
	StrCpy $0 $0 2		; "C:"
	System::Call 'kernel32::GetDriveType(t"$0")i.r0'
	${If} $1 == ":\"
	${AndIf} $0 == 3 ; 3-fixed drive
		EnableWindow $mui.Button.Next 1
	${Else}
		EnableWindow $mui.Button.Next 0
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

Function OptionsPageLeave
	${NSD_GetText} $TSselector_DL $TS_toInstall
	${NSD_GetText} $InstDir_DR $INSTDIR
	SendMessage $mui.Button.Next ${WM_SETFONT} $origNextFont 0 ; восстанавливаем шрифт кнопки "далее"
FunctionEnd

Function FinishPageShow ; добавляем свои чекбоксы на финишную страницу
	Push $0
	
	Var /GLOBAL _Autostart_
	${NSD_CreateCheckbox} 120u 104u 100% 10u "$(_LAUNCH_ON_LOGON_)"
	Pop $_Autostart_
	${NSD_SetState} $_Autostart_ ${BST_CHECKED}
	SetCtlColors $_Autostart_ "" "ffffff"

	Var /GLOBAL _Shortcut_
	${NSD_CreateCheckbox} 120u 117u 100% 10u "$(_DESKTOP_SHORTCUT_)"
	Pop $_Shortcut_
	${NSD_SetState} $_Shortcut_ ${BST_CHECKED}
	SetCtlColors $_Shortcut_ "" "ffffff"

	Var /GLOBAL _Autoupdate_
	${NSD_CreateCheckbox} 120u 131u 100% 10u "$(_AUTOUPDATE_)"
	Pop $_Autoupdate_
	SetCtlColors $_Autoupdate_ "" "ffffff"

	Var /GLOBAL _FWrule_
	${NSD_CreateCheckbox} 120u 145u 100% 10u "$(_ADD_FWRULE_EXCEPTIONS_)"
	Pop $_FWrule_
	SetCtlColors $_FWrule_ "" "ffffff"

	Var /GLOBAL _Chrome_
	${NSD_CreateRadioButton} 120u 163u 100% 10u "$(_CHROME_EXTENSION_) (web)"
	Pop $_Chrome_
	SetCtlColors $_Chrome_CHB "" "ffffff"

	Var /GLOBAL _Firefox_
	${NSD_CreateRadioButton} 120u 175u 100% 10u "$(_FIREFOX_EXTENSION_) (web)"
	Pop $_Firefox_
	SetCtlColors $_Firefox_CHB "" "ffffff"

	; проверка доступности брандмауэра удалением правила. если доступен - выставляем галку, если нет - скрываем чекбокс
	!insertmacro fwRuleRemove "$INSTDIR\$TSexe" $0
	${If} $0 == 0
		${NSD_SetState} $_FWrule_ ${BST_CHECKED}
	${Else}
		ShowWindow $_FWrule_ ${SW_HIDE}
	${EndIf}

	; чекбокс автообновления не показываем в WinXP или при отсутствии админских прав
	UserInfo::GetAccountType
	Pop $0
	${If} $0 == "admin"	
	${AndIf} ${AtLeastWin7}
		${NSD_SetState} $_Autoupdate_ ${AUTOUPDATESTATE}
	${Else}
		ShowWindow $_Autoupdate_ ${SW_HIDE}
	${EndIf}
	
	Pop $0
FunctionEnd

Function FinishPageLeave ; обрабатываем финишные чекбоксы
	Push $0	
	HideWindow
	
	${NSD_GetState} $mui.FinishPage.Run $RunOnComplete

	${NSD_GetState} $_Autostart_ $0
	${If} $0 == ${BST_CHECKED}
		WriteRegStr HKCU "${REG_RUN_SUBKEY}" "${APPNAME}" '"$INSTDIR\tsl.exe" --silent'
	${Else}
		DeleteRegValue HKCU "${REG_RUN_SUBKEY}" "${APPNAME}"
	${EndIf}

	${NSD_GetState} $_Shortcut_ $0
	${If} $0 == ${BST_CHECKED}
		CreateShortCut "$DESKTOP\${APPNAME}.lnk" '"$INSTDIR\tsl.exe"'
	${Else}
		Delete "$DESKTOP\${APPNAME}.lnk"
	${EndIf}

	!insertmacro AutoupdateTaskRemove
	${NSD_GetState} $_Autoupdate_ $0
	${If} $0 == ${BST_CHECKED}
		!insertmacro AutoupdateTaskCreate
	${EndIf}

	${NSD_GetState} $_FWrule_ $0
	${If} $0 == ${BST_CHECKED}
		!insertmacro fwRuleCreate "$INSTDIR\$TSexe" $0
	${EndIf}

	${NSD_GetState} $_Chrome_ $0
	${If} $0 == ${BST_CHECKED}
		ExecShell "open" "https://chrome.google.com/webstore/detail/torrserver-adder/ihphookhabmjbgccflngglmidjloeefg"
	${EndIf}

	${NSD_GetState} $_Firefox_ $0
	${If} $0 == ${BST_CHECKED}
		ExecShell "open" "https://addons.mozilla.org/firefox/addon/torrserver-adder"
	${EndIf}
	
	Pop $0
FunctionEnd

!macro tslShortcut arg
	CreateShortCut "${SHORTCUTSDIR}\tsl.exe ${arg}.lnk" "$INSTDIR\tsl.exe" "${arg}"
!macroend

!macro commonInstallSection
	Push  $0
	SetOutPath "$INSTDIR"
	AccessControl::GrantOnFile  "$INSTDIR" "(S-1-1-0)" "FullAccess"	; права на папку торрсервера все для всех
	Pop  $0
	!insertmacro CloseTS $RunOnComplete						; стопорим сервер(если запущен), запоминаем был ли запущен tsl на момент установки(понадобится при скрытой установке)
 	RMDir /r "$INSTDIR\Setup"								; удаляем неиспользуемые остатки от v.2
	DeleteRegValue HKCU "${REG_UNINST_SUBKEY}" "TSLVersion"	; -//-, версию tsl больше не храним, всегда ставим последнюю при обновлении TS
	Delete "$INSTDIR\1"										; удаляем логи от ExecDos:: которые могли появится в v.2
	; SetOverwrite off       									; создаем базы если они еще не существуют
	; File "files\db\torrserver.db"								; базы с отключенным μTP и предзагрузкой 20/32мб
	; File "files\db\config.db"
	SetOverwrite on
	WriteUninstaller "$INSTDIR\${UNINSTALLER}"				; деинсталлятор

	; создаем записи в реестре
	WriteRegStr HKCU "Software\${APPNAME}" "" "$INSTDIR"
	WriteRegStr HKCU "${REG_UNINST_SUBKEY}" "DisplayName" "${APPNAME}"
	WriteRegStr HKCU "${REG_UNINST_SUBKEY}" "DisplayVersion" "$TS_toInstall"
	WriteRegStr HKCU "${REG_UNINST_SUBKEY}" "UninstallString" '"$INSTDIR\${UNINSTALLER}"'
	WriteRegStr HKCU "${REG_UNINST_SUBKEY}" "ModifyPath" '"$INSTDIR\${ONLINE_INSTALLER}" /SkipWelcome'
	WriteRegStr HKCU "${REG_UNINST_SUBKEY}" "DisplayIcon" '"$INSTDIR\tsl.exe",0'
	WriteRegStr HKCU "${REG_UNINST_SUBKEY}" "Publisher" "${PRODUCT_PUBLISHER}"
	WriteRegDWORD HKCU "${REG_UNINST_SUBKEY}" "NoModify" 0
	WriteRegDWORD HKCU "${REG_UNINST_SUBKEY}" "NoRepair" 1

	; создаем папку ярлыков запуска tsl
	CreateDirectory "${SHORTCUTSDIR}"
	CreateShortCut "${SHORTCUTSDIR}\tsl.exe.lnk" "$INSTDIR\tsl.exe"
	!insertmacro tslShortcut "--start"
	; !insertmacro tslShortcut "--stop"
	!insertmacro tslShortcut "--close"
	!insertmacro tslShortcut "--restart"
	!insertmacro tslShortcut "--show"
	!insertmacro tslShortcut "--hide"
	!insertmacro tslShortcut "--web"

	; создаем папку ссылок
	CreateDirectory "${LINKSDIR}"
	WriteIniStr "${LINKSDIR}\$(_CHROME_EXTENSION_).url" "InternetShortcut" "URL" "https://chrome.google.com/webstore/detail/torrserver-adder/ihphookhabmjbgccflngglmidjloeefg"
	WriteIniStr "${LINKSDIR}\$(_FIREFOX_EXTENSION_).url" "InternetShortcut" "URL" "https://addons.mozilla.org/firefox/addon/torrserver-adder"
	WriteIniStr "${LINKSDIR}\TorrServer.url" "InternetShortcut" "URL" "https://github.com/YouROK/TorrServer"
	WriteIniStr "${LINKSDIR}\TSL.url" "InternetShortcut" "URL" "https://github.com/Noperkot/TSL"

	; создаем папку в меню "Старт"
	RMDir /r "$SMPROGRAMS\${APPNAME}"
	CreateDirectory "$SMPROGRAMS\${APPNAME}"
	CreateShortCut "$SMPROGRAMS\${APPNAME}\$(_LAUNCH_) ${APPNAME}.lnk" "$INSTDIR\tsl.exe"
	CreateShortCut "$SMPROGRAMS\${APPNAME}\$(_UPDATE_) ${APPNAME}.lnk" "$INSTDIR\${ONLINE_INSTALLER}" "/SkipWelcome"
	CreateShortCut "$SMPROGRAMS\${APPNAME}\$(_UNINSTALL_) ${APPNAME}.lnk" "$INSTDIR\${UNINSTALLER}"
	; CreateShortCut "$SMPROGRAMS\${APPNAME}\$(_LINKS_).lnk" "${LINKSDIR}"
	Pop  $0
!macroend

Section Uninstall
	; стопорим сервер(если запущен)
	!insertmacro CloseTS $0
	;Remove from registry...
	DeleteRegKey HKCU "${REG_UNINST_SUBKEY}"
	DeleteRegKey HKCU "Software\${APPNAME}"
	DeleteRegValue HKCU "${REG_RUN_SUBKEY}" "${APPNAME}"
	; Delete Shortcuts
	Delete "$DESKTOP\${APPNAME}.lnk"
	RMDir /r "$SMPROGRAMS\${APPNAME}"
	; Delete autoupdate task
	!insertmacro AutoupdateTaskRemove
	; Delete firewall rules
	!insertmacro fwRuleRemove "$INSTDIR\${TS32EXE}" $0
	!insertmacro fwRuleRemove "$INSTDIR\${TS64EXE}" $0
	; Clean up Application
	Delete "$INSTDIR\tsl.exe"
	Delete "$INSTDIR\${TS32EXE}"
	Delete "$INSTDIR\${TS64EXE}"
	Delete "$INSTDIR\config.db"
	Delete "$INSTDIR\viewed.json"
	Delete "$INSTDIR\settings.json"
	Delete "$INSTDIR\torrserver.db"
	Delete "$INSTDIR\torrserver.db.lock"
	Delete "$INSTDIR\rutor.ls"
	Delete "$INSTDIR\${ONLINE_INSTALLER}"
	RMDir /r "$INSTDIR\Ссылки"
	RMDir /r "${LINKSDIR}"
	RMDir /r "${SHORTCUTSDIR}"
	Delete "$INSTDIR\${UNINSTALLER}"
	Sleep 500
	RMDir "$INSTDIR"
SectionEnd

Section Abort Abort_ID
	${If} $AbortMessage != ""
		DetailPrint "$AbortMessage"
		DetailPrint "$(_INSTALLATION_FAILED_)"
		SetDetailsView show
		Abort
	${EndIf}
SectionEnd

Function .onInit
	Push $0	
/*
 	${IfNot} ${AtLeastWin7}	; NSxfer под XP с github работать не будет (tls 1.2)
		MessageBox MB_OK|MB_ICONSTOP "$(_REQUIRES_WIN7_)" /SD IDOK
		Quit
	${EndIf} 
*/
	;
	!insertmacro CheckMutex	; проверка уже запущенного экземпляра установщика
	;
 	; имя экзешника ТС в зависимости от разрядности ОС
	${If} ${RunningX64}
		Push ${TS64EXE} ; если тут сразу присваивать StrCpy $TSexe ${TS64EXE} то на VT поднимается целый гвалт
	${Else}
		Push ${TS32EXE}
	${EndIf}
	Pop $TSexe
	;
	ClearErrors
	ReadRegStr $0 HKCU "Software\${APPNAME}" ""				; проверка существующей установки
	${IfNot} ${Errors}										; если уже установлено
		${StrRep} $0 $0 '"' ''								; в старых версиях установщика путь писался в кавычках, удаляем их
		StrCpy $INSTDIR $0									; берем путь установки
	${EndIf}
	;
	ReadRegStr $TS_Installed HKCU "${REG_UNINST_SUBKEY}" "DisplayVersion"	; получаем версию установленного TS
	StrCpy $TempDir "$PLUGINSDIR" ; \downloads
	Pop $0
FunctionEnd

Function un.onInit
	!insertmacro CheckMutex
FunctionEnd

Function .onInstSuccess
	${If} $RunOnComplete != ${BST_UNCHECKED}
		; перед запуском убиваем левые процессы торрсервера
		KillProcDLL::KillProc "${TS32EXE}"
		KillProcDLL::KillProc "${TS64EXE}"
		KillProcDLL::KillProc "TorrServer.exe"
		Exec '"$INSTDIR\tsl.exe" --start'
	${EndIf}
FunctionEnd

; LangString _REQUIRES_WIN7_ ${LANG_RUSSIAN} "Требуется Windows 7 или выше" ; $(_REQUIRES_WIN7_)
; LangString _REQUIRES_WIN7_ ${LANG_ENGLISH} "Requires Windows 7 or higher"

LangString _UNEXPECTED_ERROR_ ${LANG_RUSSIAN} "Непредвиденная ошибка" ; $(_UNEXPECTED_ERROR_)
LangString _UNEXPECTED_ERROR_ ${LANG_ENGLISH} "Unexpected error"

LangString _ALREADY_RUNNING_ ${LANG_RUSSIAN} "Установка уже выполняется" ; $(_ALREADY_RUNNING_)
LangString _ALREADY_RUNNING_ ${LANG_ENGLISH} "The installer is already running"

LangString _REINSTALL_SUBTEXT_ ${LANG_RUSSIAN} "Переустановка возможна только в существующую папку. Для выбора другого расположения удалите TorrServer и выполните установку заново." ; $(_REINSTALL_SUBTEXT_)
LangString _REINSTALL_SUBTEXT_ ${LANG_ENGLISH} "Reinstalling is only possible in an existing folder. To select a different location, delete TorrServer and perform the installation again."

LangString _CHROME_EXTENSION_ ${LANG_RUSSIAN} "Расширениe Chrome" ; $(_CHROME_EXTENSION_)
LangString _CHROME_EXTENSION_ ${LANG_ENGLISH} "Chrome Extensions"

LangString _FIREFOX_EXTENSION_ ${LANG_RUSSIAN} "Расширениe Firefox" ; $(_FIREFOX_EXTENSION_)
LangString _FIREFOX_EXTENSION_ ${LANG_ENGLISH} "Firefox Extensions"

LangString _ADD_FWRULE_EXCEPTIONS_ ${LANG_RUSSIAN} "Добавить в исключения брандмауэра" ; $(_ADD_FWRULE_EXCEPTIONS_)
LangString _ADD_FWRULE_EXCEPTIONS_ ${LANG_ENGLISH} "Add to firewall exceptions"

LangString _AUTOUPDATE_ ${LANG_RUSSIAN} "Автообновление" ; $(_AUTOUPDATE_)
LangString _AUTOUPDATE_ ${LANG_ENGLISH} "Autoupdate"

LangString _LAUNCH_ON_LOGON_ ${LANG_RUSSIAN} "Запускать при входе в Windows" ; $(_LAUNCH_ON_LOGON_)
LangString _LAUNCH_ON_LOGON_ ${LANG_ENGLISH} "Launch on logon"

LangString _DESKTOP_SHORTCUT_ ${LANG_RUSSIAN} "Ярлык на Рабочий стол" ; $(_DESKTOP_SHORTCUT_)
LangString _DESKTOP_SHORTCUT_ ${LANG_ENGLISH} "Create shortcut on Desktop"

; LangString _LINKS_ ${LANG_RUSSIAN} "Ссылки" ; $(_LINKS_)
; LangString _LINKS_ ${LANG_ENGLISH} "Links"

LangString _LAUNCH_ ${LANG_RUSSIAN} "Запустить" ; $(_LAUNCH_)
LangString _LAUNCH_ ${LANG_ENGLISH} "Launch"

LangString _UPDATE_ ${LANG_RUSSIAN} "Обновить" ; $(_UPDATE_)
LangString _UPDATE_ ${LANG_ENGLISH} "Update"

LangString _UNINSTALL_ ${LANG_RUSSIAN} "Удалить" ; $(_UNINSTALL_)
LangString _UNINSTALL_ ${LANG_ENGLISH} "Uninstall"

LangString _NO_UPDATES_FOUND_ ${LANG_RUSSIAN} "Установлена последняя версия" ; $(_NO_UPDATES_FOUND_)
LangString _NO_UPDATES_FOUND_ ${LANG_ENGLISH} "Latest version installed"

LangString _REINSTALL_ ${LANG_RUSSIAN} "Пере&установить" ; $(_REINSTALL_)
LangString _REINSTALL_ ${LANG_ENGLISH} "Re&install"

LangString _CUSTOM_PAGE_TITLE_ ${LANG_RUSSIAN} "Параметры установки" ; $(_CUSTOM_PAGE_TITLE_)
LangString _CUSTOM_PAGE_TITLE_ ${LANG_ENGLISH} "Installation Options"

LangString _NEW_VERSION_ ${LANG_RUSSIAN} "новая версия" ; $(_NEW_VERSION_)
LangString _NEW_VERSION_ ${LANG_ENGLISH} "new version"

LangString _INSTALLATION_FAILED_ ${LANG_RUSSIAN} "УСТАНОВКА НЕ УДАЛАСЬ" ; $(_INSTALLATION_FAILED_)
LangString _INSTALLATION_FAILED_ ${LANG_ENGLISH} "INSTALLATION FAILED"

LangString _TASK_DESCRIPTION_ ${LANG_RUSSIAN} "Обновление ${APPNAME}" ; $(_TASK_DESCRIPTION_)
LangString _TASK_DESCRIPTION_ ${LANG_ENGLISH} "${APPNAME} update"