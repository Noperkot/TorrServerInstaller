Unicode True

!ifndef TSVER
	!define TSVER "1.1.65"
!endif
!ifndef TSDIR
	!define TSDIR  "files\incexe\TorrServers"
!endif




!ifndef TSL_VERSION
	!define TSL_VERSION "1.7.1" ; "1.8.1" ; !!!!!!!!!!!!!!!!!!! поменять на новый релиз !!!!!!!!!!!!!!!!!!!!!!
!endif



!ifndef INSTALLER
	!define INSTALLER "TorrServer_${TSVER}_Setup.exe"
!endif
!define CAPTION "TorrServer ${TSVER} Installer"
!define AUTHORS "YouROK, Noperkot"
!define INSTALLICON "offline.ico"
!define PRODUCT_VERSION "TS-${TSVER}, TSL-${TSL_VERSION}"
!define AUTOUPDATESTATE ${BST_UNCHECKED}

!macro Preinstall
!macroend

!include common.nsh

Section Install Install_ID
	!insertmacro commonInstallSection
	File "files\incexe\online_installer\${VERSION}\${ONLINE_INSTALLER}"	; онлайн инсталлятор
	File "files\incexe\TSL\${TSL_VERSION}\tsl.exe"
	${If} $TSexe == "TorrServer-windows-amd64.exe"
		File "${TSDIR}\${TSVER}\TorrServer-windows-amd64.exe"
	${Else}
		File "${TSDIR}\${TSVER}\TorrServer-windows-386.exe"
	${EndIf}
SectionEnd

Function fillTSselector
	StrCpy $TS_toInstall ${TSVER}
	${NSD_CB_AddString} $TSselector_DL  $TS_toInstall
FunctionEnd