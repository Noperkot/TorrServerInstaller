Unicode True

!ifndef TSVER
	!define TSVER "1.1.65"
!endif
!ifndef TSDIR
	!define TSDIR  "files\incexe\TorrServers"
!endif

!ifndef TSL_VERSION
	!define TSL_VERSION "1.8.1"
!endif

!ifndef INSTALLER
	!define INSTALLER "TorrServer_${TSVER}_Setup.exe"
!endif
!define CAPTION "TorrServer ${TSVER} Installer"
!define AUTHORS "YouROK, Noperkot"
!define INSTALLICON "offline.ico"
!define PRODUCT_VERSION "TS-${TSVER}, TSL-${TSL_VERSION}"
!define AUTOUPDATESTATE ${BST_UNCHECKED}

!macro GetVersions
!macroend

!include common.nsh

Section Install Install_ID
	!insertmacro preInstall
	${If} $TSexe == "TorrServer-windows-amd64.exe"
		File "${TSDIR}\${TSVER}\TorrServer-windows-amd64.exe"
	${Else}
		File "${TSDIR}\${TSVER}\TorrServer-windows-386.exe"
	${EndIf}
	File "files\incexe\TSL\${TSL_VERSION}\tsl.exe"
	File "files\incexe\online_installer\${VERSION}\${ONLINE_INSTALLER}"	; онлайн инсталлятор
	!insertmacro postInstall
SectionEnd

Function fillTSselector
	StrCpy $TS_toInstall ${TSVER}
	${NSD_CB_AddString} $TSselector_DL  $TS_toInstall
FunctionEnd