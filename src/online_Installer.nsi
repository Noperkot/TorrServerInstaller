Unicode True

!define INSTALLER "TorrServer_Setup.exe"
!define CAPTION "TorrServer Online Installer"
!define AUTHORS "Noperkot"
!define INSTALLICON "online.ico"
!define AUTOUPDATESTATE ${BST_CHECKED}
!define TOINSTALLARG "/TS="
!define MUI_CUSTOMFUNCTION_GUIINIT onGUIInit

!macro Preinstall
	!define MUI_PAGE_HEADER_TEXT "$(_PREINSTALL_TEXT_)"
	!define MUI_PAGE_HEADER_SUBTEXT "$(_PREINSTALL_SUBTEXT_)"
	!define MUI_INSTFILESPAGE_FINISHHEADER_TEXT "$(_PREINSTALL_TEXT_)"
	!define MUI_INSTFILESPAGE_FINISHHEADER_SUBTEXT "$(^Completed)"
	!insertmacro MUI_PAGE_INSTFILES
!macroend

!include common.nsh

Function Download
	Exch $0 ; ${file}
	Exch
	Exch $1 ; ${url}
	SetDetailsPrint listonly
	DetailPrint "$(_DOWNLOAD_) $1 -> $0"
	SetDetailsPrint both
	NScurl::http GET "$1" "$0" /CACERT "" /CANCEL /TIMEOUT 30000 /END
	; NSxfer::Transfer /URL "$1" /LOCAL "$0" /ABORT "" "" /TIMEOUTCONNECT 30000 /END ; под XP с гитхабом не работает, но зато библиотека крошечная...
	Pop $1
	${If} $1 != "OK"
		${_abort_} "    !!! $(^CouldNotLoad) $1 !!!"
	${EndIf}
	Pop $1
	Pop $0
FunctionEnd

!macro Download url file
	Push ${url}
	Push ${file}
	Call Download
!macroend

Section preInstall preInstall_ID  ; секция получения списка доступных версий TS
	${GetOptions} $CMDLINE ${TOINSTALLARG} $TS_toInstall	; параметром командной строки /TS= можно указать желаемую версию торрсервера даже если ее нет в списке
	${If} $TS_toInstall == ""
		${If} ${AtLeastWin7}
			DetailPrint "$(_PREINSTALL_TEXT_)..."
			${If} ${Silent}
				StrCpy $R0 "1" ; один последний релиз (в сайленте только проверка обновлений, незачем качать лишний мусор)
			${Else}
				StrCpy $R0 "20" ; 20 последних релизов
			${EndIf}
			StrCpy $R1 "$TempDir\ts.json"
			!insertmacro Download "https://api.github.com/repos/YouROK/TorrServer/releases?per_page=$R0" "$R1"
			DetailPrint "$(_PARSING_) $R1"
			ClearErrors
			nsJSON::Set /file "$R1"
			${If} ${Errors}
				${_abort_} "$(_FILE_ERROR_) $R1"
			${EndIf}
			nsJSON::Get /index 0 "tag_name" /end ; для установки выбираем последний релиз
			${If} ${Errors}
				${_abort_} "$(_PARSING_ERROR_) $R1"
			${EndIf}
		${Else}
			Push "1.1.77" ; последний релиз TS для WinXP
		${EndIf}
		Pop $TS_toInstall
	${EndIf}
	${If} ${Silent}
	${AndIf} $TS_Installed == $TS_toInstall ; Обновлений нет, установку отменяем
		SetErrorlevel 0 ; для планировщика
		Abort
	${EndIf}
SectionEnd

!macro Move file
	Delete "$INSTDIR\${file}"
	Rename "$TempDir\${file}" "$INSTDIR\${file}"
	AccessControl::EnableFileInheritance "$INSTDIR\${file}"
	Pop  $0
!macroend

Section  Install Install_ID ; секция установки
 	DetailPrint "$(_DOWNLOAD_) $(_COMPONENTS_)..."
	!insertmacro Download "https://github.com/YouROK/TorrServer/releases/download/$TS_toInstall/$TSexe" "$TempDir\$TSexe"
	!insertmacro Download "https://github.com/Noperkot/TSL/releases/latest/download/tsl.exe" "$TempDir\tsl.exe"
	DetailPrint "$(_DOWNLOAD_) $(_COMPLETE_)"
	!insertmacro commonInstallSection
	!insertmacro Move "$TSexe"
	!insertmacro Move "tsl.exe"
	${If} "$EXEDIR" != "$INSTDIR"
		CopyFiles /SILENT "$EXEPATH" "$INSTDIR\${ONLINE_INSTALLER}"
	${EndIf}
SectionEnd

Function fillTSselector
	Push $0
	Push $1
	Push $2
	Push $3
	Push $R1
	ClearErrors
	${GetOptions} $CMDLINE ${TOINSTALLARG} $0 ; если версия задана параметром "/TS=" селектор не заполняем
	${If} ${Errors}
		; В список выбора версии TS добавляем последние 20 штук с гитхаба(но не старше MatriX.114) плюс кое-что из старых	
		${If} ${AtLeastWin7}
			StrCpy $R1 "$TempDir\ts.json"
			ClearErrors
			nsJSON::Get /count /end
			${If} ${Errors}
				${_abort_} '$(_PARSING_ERROR_) "$R1"'
				${EndIf}
			Pop $1
			IntOp $1 $1 - 1
			${ForEach} $2 0 $1 + 1
				nsJSON::Get /index $2 "tag_name" /end
				${If} ${Errors}
					${_abort_} '$(_PARSING_ERROR_) "$R1"'
				${EndIf}
				Pop $3
				${NSD_CB_AddString} $TSselector_DL "$3"
				${If} $3 == "MatriX.114"
					${Break}
				${EndIf}
			${Next}
			nsJSON::Delete /end
			${NSD_CB_AddString} $TSselector_DL  "MatriX.112"
			${NSD_CB_AddString} $TSselector_DL  "MatriX.110"
			${NSD_CB_AddString} $TSselector_DL  "MatriX.109"
			${NSD_CB_AddString} $TSselector_DL  "MatriX.106"
		${EndIf}
		${NSD_CB_AddString} $TSselector_DL  "1.1.77"
		${NSD_CB_AddString} $TSselector_DL  "1.1.68"
		${NSD_CB_AddString} $TSselector_DL  "1.1.65"
		EnableWindow $TSselector_DL 1					; активируем селектор
	${Else} ; версия ТС была задана параметром командной строки
		${NSD_CB_AddString} $TSselector_DL  $TS_toInstall
	${EndIf}
	SectionSetFlags ${preInstall_ID} 0				; выключаем секцию preInstall
	SectionSetFlags ${Install_ID} ${SF_SELECTED}	; включаем секцию Install
	Pop $R1
	Pop $3
	Pop $2
	Pop $1
	Pop $0
FunctionEnd

Function onGUIInit
	SectionSetFlags ${Install_ID} 0	; выключаем секцию Install в визуальном режиме
FunctionEnd

LangString _PREINSTALL_TEXT_ ${LANG_RUSSIAN} "Получение версий" ; $(_PREINSTALL_TEXT_)
LangString _PREINSTALL_TEXT_ ${LANG_ENGLISH} "Getting versions"

LangString _PREINSTALL_SUBTEXT_ ${LANG_RUSSIAN} "Поиск версий компонентов" ; $(_PREINSTALL_SUBTEXT_)
LangString _PREINSTALL_SUBTEXT_ ${LANG_ENGLISH} "Searching for components versions"

LangString _FILE_ERROR_ ${LANG_RUSSIAN} "Файл поврежден" ; $(_FILE_ERROR_)
LangString _FILE_ERROR_ ${LANG_ENGLISH} "File is corrupted"

LangString _PARSING_ERROR_ ${LANG_RUSSIAN} "Ошибка парсинга" ; $(_PARSING_ERROR_)
LangString _PARSING_ERROR_ ${LANG_ENGLISH} "Parsing error"

LangString _DOWNLOAD_ ${LANG_RUSSIAN} "Загрузка" ; $(_DOWNLOAD_)
LangString _DOWNLOAD_ ${LANG_ENGLISH} "Download"

LangString _COMPONENTS_ ${LANG_RUSSIAN} "компонентов" ; $(_COMPONENTS_)
LangString _COMPONENTS_ ${LANG_ENGLISH} "components"

LangString _COMPLETE_ ${LANG_RUSSIAN} "завершена" ; $(_COMPLETE_)
LangString _COMPLETE_ ${LANG_ENGLISH} "complete"

LangString _PARSING_ ${LANG_RUSSIAN} "Парсинг" ; $(_PARSING_)
LangString _PARSING_ ${LANG_ENGLISH} "Parsing"