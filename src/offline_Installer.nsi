!ifndef TS_VERSION
	!define TS_VERSION "MatriX.129"
!endif
!define TSL_VERSION "1.7.1"
!define INSTALLER "TorrServer_${TS_VERSION}_Setup.exe"
!define CAPTION "TorrServer ${TS_VERSION} Installer"
!define AUTHORS "YouROK, Noperkot"
!define PRODUCT_VERSION "TS-${TS_VERSION}, TSL-${TSL_VERSION}"
!define TSDIR "TorrServers\${TS_VERSION}"
!define SIGNEDDIR "files\signed"

!macro getVersions
	StrCpy $TorrServer_ver ${TS_VERSION}
	StrCpy $TSL_ver ${TSL_VERSION}
!macroend

!include common.nsh

Section Install
	!insertmacro commonInstallSection
	File "${SIGNEDDIR}\${ONLINE_INSTALLER}"	; онлайн инсталлятор
	File "${SIGNEDDIR}\${TSLEXE}" ; tsl.exe
	${If} ${RunningX64}
		File "${TSDIR}\TorrServer-windows-amd64.exe"
	${Else}
		File "${TSDIR}\TorrServer-windows-386.exe"
	${EndIf}
SectionEnd

Function .onInit
	SetSilent normal
FunctionEnd