#!/bin/bash
# Control the Somfy blind motor with VIMAR By-me actuator
#
# Giuseppe Ursino 2020.
#set -x

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


function ResetByme() {
  Clear
  Print "Reset AdjFB"
  SendMsg "BC 110F 21D6 E1 00 81"
  Pause
  Print "Set new AdjFB"

  Print "Set GO UP"
  Print "Set GO DOWN"
  Pause
}

function ResetSomfyMotor() {
  NotImplemented
  Clear
  Print "Reset motor to default settings: UP+DOWN for 8s"
  Pause
}

function SetupBlindLimit() {
  NotImplemented
  Clear
  Print "UP + DOWN for 3s"
  Print "> Have you seen blind UP/DOWN movement?"
  Pause
  Print "UP for 3s"
  Print "> Have you seen blind UP/DOWN movement?"
  Pause
  Print "Manual DOWN/UP until blind is closed"
  Pause
  Print "> Do you want to memo the blind bottom limit?"
  Pause
  Print "UP for 0.5s"
  Print "UP for 3s"
  Print "> Have you seen blind UP/DOWN movement?"
  Pause
  Print "UP + DOWN for 3s"
  Print "> Have you seen blind UP/DOWN movement?"
  Pause
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


