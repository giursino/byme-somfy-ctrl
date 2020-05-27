#!/bin/bash
# Control the Somfy blind motor
#
# Giuseppe Ursino 2020.
#set -x

SCRIPTNAME=$1

GOWRITE="/usr/src/bcusdk/eibd/examples/GU_groupwrite"
EIBDURL="local:/tmp/eib"

######### USCITA
# param $1: codice di uscita
function uscita()
{
  `which clear`
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
	MENUID=`eval $MENUCMD` || uscita 0
	if [[ $MENUID == 1 ]]; then
		echo "send on..."
		$GOWRITE $EIBDURL $GOADDR 0x81
	elif [[ $MENUID == 2 ]]; then
		echo "send off..."
		$GOWRITE $EIBDURL $GOADDR 0x80
	else
		uscita 0
	fi
}



########## ABSOLUTE <GO_ADDR>
function absoluteSet()
{
	GOADDR=$1
	TITLE="Value"
	TEXT="Insert value to send:"
	CMD=`printf "%s --title '%s' --inputbox '%s' 24 48 0x00 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT"`
	OUT=`eval $CMD` || uscita 0
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
	MENUID=`eval $MENUCMD` || uscita 0
	if [[ $MENUID == 1 ]]; then
		echo "send up..."
		$GOWRITE $EIBDURL $GOADDR 0x89
	elif [[ $MENUID == 2 ]]; then
		echo "send down..."
		$GOWRITE $EIBDURL $GOADDR 0x81
	else
		uscita 0
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
		uscita 0
	fi
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
		uscita 0
	fi
}


function ResetByme() {
  NotImplemented
}

function ResetSomfyMotor() {
  NotImplemented
}

function SetupBlindLimit() {
  NotImplemented
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
	MENUID=`eval $CMD` || uscita 1
	if [[ $MENUID == "q" ]]; then
		uscita 1
	fi
	if [[ $MENUID -le 9 ]]; then
		RET=`${ACTION[$MENUID]}`
		if [[ $? != 0 ]]; then
			$DIALOG --title "Error" --msgbox "$RET" 10 40
		fi
	fi
done

exit 0


