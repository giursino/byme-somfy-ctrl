#!/bin/bash
# Control the Somfy blind motor with VIMAR By-me actuator
#
# Giuseppe Ursino 2020.

# Set DEBUG to "true" or "false"
DEBUG=true
if $DEBUG; then set -x; fi

SCRIPTNAME=$1

SENDMSG="echo 01847-sendmsg"

######### EXIT HANDLER
# param $1: exit status
function byebye()
{
  `which clear` 2>&1 1>&3
	if [ -z $1 ]; then
		exit 1
	fi
	exit $1
}

DIALOG=
TMP=`mktemp`
trap 'rm -f $TMP' EXIT

if [ "$DISPLAY" != "" ]; then
    DIALOG=`which Xdialog`
    DLGOPT=--wrap
fi
if [ ! -x "$DIALOG" ]; then
    DIALOG=`which dialog`
    DLGOPT=
fi

if [ ! -x $DIALOG ] || [ -z $DIALOG ]; then
    echo $"No dialog program found. Please install Xdialog or dialog."
    exit 1
fi

DIALOG="$DIALOG $DLGOPT"

SU=`which sudo`
if [ ! -x "$SU" ]; then
    SU=`which su`
fi

########## MENU' DISPLAY <TITLE> <MENUTEXT> <ITEMS> <DEFAULT_ITEM>
function menucmd()
{
	TITLE=$1
	TEXT=$2
	ITEMS=$3
	DEF=$4
    printf "%s --title '%s' --default-item '%s' --menu '%s' 24 48 15 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$DEF" "$TEXT" "$ITEMS"
}


########## SWITCH ONOFF <GO_ADDR>
function switchOnOff()
{
	GOADDR=$1
	TITLE="Command"
	MENUTEXT="Select:"
	MENUITEMS="1 ON 2 OFF"
	MENUCMD=`printf "%s --title '%s' --menu '%s' 24 48 15 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT" "$MENUITEMS"`
	MENUID=`eval $MENUCMD` || byebye 0
	if [[ $MENUID == 1 ]]; then
		echo "send on..."
		$GOWRITE $EIBDURL $GOADDR 0x81
	elif [[ $MENUID == 2 ]]; then
		echo "send off..."
		$GOWRITE $EIBDURL $GOADDR 0x80
	else
		byebye 0
	fi
}



########## ABSOLUTE <GO_ADDR>
function absoluteSet()
{
	GOADDR=$1
	TITLE="Value"
	TEXT="Insert value to send:"
	CMD=`printf "%s --title '%s' --inputbox '%s' 24 48 0x00 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT"`
	OUT=`eval $CMD` || byebye 0
	$GOWRITE $EIBDURL $GOADDR $OUT
}


########## RELATIVE <GO_ADDR>
function relativeSet()
{
	GOADDR=$1
	TITLE="Command"
	MENUTEXT="Select:"
	MENUITEMS="1 UP 2 DOWN"
	MENUCMD=`printf "%s --title '%s' --menu '%s' 24 48 15 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT" "$MENUITEMS"`
	MENUID=`eval $MENUCMD` || byebye 0
	if [[ $MENUID == 1 ]]; then
		echo "send up..."
		$GOWRITE $EIBDURL $GOADDR 0x89
	elif [[ $MENUID == 2 ]]; then
		echo "send down..."
		$GOWRITE $EIBDURL $GOADDR 0x81
	else
		byebye 0
	fi

	TITLE="Break command"
	TEXT="Do you want to send the STOP message?"
	MENUCMD=`printf "%s --title '%s' --yesno '%s' 6 48 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT"`
	MENUID=`eval $MENUCMD`
	EXIT=$?
	if [[ $EXIT == 0 ]]; then
		#yes
		$GOWRITE $EIBDURL $GOADDR 0x80
	else
		byebye 0
	fi
}

function Print() {
  echo $1 2>&1 1>&3
}

function Clear() {
  clear 2>&1 1>&3
}

function Pause() {
  echo "Press enter to continue..." 2>&1 1>&3
  read
}

function SendMsg() {
  MSG="$1"
  $SENDMSG "$MSG" 2>&1 1>&3 || byebye 1
  return 0
}

function SwitchUP() {
  if [ $1 -eq 1 ]; then VAL="81"; else VAL="80"; fi
  SendMsg "BC 00BB 9900 E1 00 $VAL"
}

function SwitchDOWN() {
  if [ $1 -eq 1 ]; then VAL="81"; else VAL="80"; fi
  SendMsg "BC 00BB 9901 E1 00 $VAL"
}

function NotImplemented() {
	TITLE="Warning"
	TEXT="Not yet implemented"
	MENUCMD=`printf "%s --title '%s' --msgbox '%s' 6 25 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT"`
	MENUID=`eval $MENUCMD`
	EXIT=$?
	if [[ $EXIT == 0 ]]; then
		#ok
		return
	else
		byebye 0
	fi
}

function Show() {
	TITLE="Info"
	TEXT="$1"
	MENUCMD=`printf "%s --title '%s' --msgbox '%s' 6 48 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT"`
	MENUID=`eval $MENUCMD`
	EXIT=$?
	if [[ $EXIT == 0 ]]; then
		#ok
		return
	else
		byebye 0
	fi
}

function Ask() {
	TITLE="Question"
	TEXT="$1"
	MENUCMD=`printf "%s --title '%s' --yesno '%s' 6 48 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT"`
	MENUID=`eval $MENUCMD`
	EXIT=$?
	if [[ $EXIT == 0 ]]; then
		#yes
    return
	else
		byebye 0
	fi
}

function Wait() {
  for i in $(seq 0 $((100/($1-1))) 100) ; do
    echo $i | dialog --gauge "Please wait" 6 48 0 2>&1 1>&3
    sleep 1
  done
}

function ResetByme() {
  if $DEBUG; then Clear; fi

  Print "Reset AdjFB BLIND"
  SendMsg "BC 00BB 201B 66 03D7  19  FF  1001  FF"
  if $DEBUG; then Pause; fi

  Print "Set new AdjFB SWITCH UP"
  SendMsg "BC 00BB 201B 66 03D7  14  FF  1001  00"
  if $DEBUG; then Pause; fi

  Print "Set new AdjFB SWITCH DOWN"
  SendMsg "BC 00BB 201B 66 03D7  15  FF  1001  00"
  if $DEBUG; then Pause; fi

  Print "Set GO link UP"
  SendMsg "BC 00BB 201B 65 03E7  7E  01  9900 "
  if $DEBUG; then Pause; fi

  Print "Set GO link DOWN"
  SendMsg "BC 00BB 201B 65 03E7  85  01  9901 "
  if $DEBUG; then Pause; fi

  Show "It works! I have changed By-me device configuration.\nWarning to move the blind."
}

function ResetSomfyMotor() {
  Ask "Are you sure to start factory reset procedure?"

  Print "Reset motor to default settings: UP+DOWN for 8s"
  SwitchUP 1
  SwitchDOWN 1
  Wait 8
  SwitchUP 0
  SwitchDOWN 0

  Ask "Have you seen blind UP/DOWN movement *two* times?"

  Show "It works!"
}

function SetupBlindLimit() {
  Ask "Are you sure to setup the blind bottom limit?"

  Print "UP + DOWN for 3s"
  SwitchUP 1
  SwitchDOWN 1
  Wait 3
  SwitchUP 0
  SwitchDOWN 0
  Ask "Have you seen blind UP/DOWN movement?"

  Print "UP for 3s"
  SwitchUP 1
  Wait 3
  SwitchUP 0
  Ask "Have you seen blind UP/DOWN movement?"

  Print "Manual DOWN/UP until blind is closed"
  Pause

  Ask "Do you want to memo the blind bottom limit?"
  Print "UP for a short time"
  SwitchUP 1
  sleep 0.2
  SwitchUP 0
  sleep 0.3
  Print "UP for 3s"
  SwitchUP 1
  Wait 3
  SwitchUP 0
  Ask "Have you seen blind UP/DOWN movement?"

  Print "UP + DOWN for 3s"
  SwitchUP 1
  SwitchDOWN 1
  Wait 3
  SwitchUP 0
  SwitchDOWN 0
  Ask "Have you seen blind UP/DOWN movement?"

  Show "It works!"
}

function ChangeBlindLimit() {
  NotImplemented
}

function ManualMode() {
  NotImplemented
}


############# MENU ITEM


I=0
MENUITEM[$I]="$I \"Reset By-me FB\""
ACTION[$I]="ResetByme"

let I++
MENUITEM[$I]="$I \"Reset Somfy motor\""
ACTION[$I]="ResetSomfyMotor"

let I++
MENUITEM[$I]="$I \"Setup blind limit\""
ACTION[$I]="SetupBlindLimit"

let I++
MENUITEM[$I]="$I \"Change blind limit - optional\""
ACTION[$I]="ChangeBlindLimit"

let I++
MENUITEM[$I]="$I \"Manual mode\""
ACTION[$I]="ManualMode"

let I++
MENUITEM[$I]="q QUIT"



################################################## MAIN

while [ 1 ]; do
	exec 3>&1
	CMD=`menucmd "Actions" "Select action:" "${MENUITEM[*]}" $MENUID`
	MENUID=`eval $CMD` || byebye 1
	if [[ $MENUID == "q" ]]; then
		byebye 1
	fi
	if [[ $MENUID -le 9 ]]; then
		RET=`${ACTION[$MENUID]}`
		if [[ $? != 0 ]]; then
			$DIALOG --title "Error" --msgbox "$RET" 10 40
		fi
	fi
done

exit 0


