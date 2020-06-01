#!/bin/bash
# Control the Somfy blind motor with VIMAR By-me actuator
#
# Giuseppe Ursino 2020.

# Set DEBUG to "true" or "false"
#DEBUG=true
DEBUG=false
if $DEBUG; then set -x; fi

SCRIPTNAME=$1

SENDMSG="01847-sendmsg"
SRCADDR="00BB"

######### EXIT HANDLER
# param $1: exit status
function byebye()
{
  $(which clear) 2>&1 1>&3
  if [ -z $1 ]; then
    exit 1
  fi
  exit $1
}

DIALOG=

if [ "$DISPLAY" != "" ]; then
  DIALOG=$(which Xdialog)
  DLGOPT=--wrap
fi
if [ ! -x "$DIALOG" ]; then
  DIALOG=$(which dialog)
  DLGOPT=
fi

if [ ! -x $DIALOG ] || [ -z $DIALOG ]; then
  echo $"No dialog program found. Please install Xdialog or dialog."
  exit 1
fi

DIALOG="$DIALOG $DLGOPT"

SU=$(which sudo)
if [ ! -x "$SU" ]; then
  SU=$(which su)
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
  SendMsg "BC $SRCADDR 9900 E1 00 $VAL"
}

function SwitchDOWN() {
  if [ $1 -eq 1 ]; then VAL="81"; else VAL="80"; fi
  SendMsg "BC $SRCADDR 9901 E1 00 $VAL"
}

function NotImplemented() {
  TITLE="Warning"
  TEXT="Not yet implemented"
  MENUCMD=$(printf "%s --title '%s' --msgbox '%s' 6 25 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT")
  MENUID=$(eval $MENUCMD)
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
  MENUCMD=$(printf "%s --title '%s' --msgbox '%s' 6 48 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT")
  MENUID=$(eval $MENUCMD)
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
  MENUCMD=$(printf "%s --title '%s' --yesno '%s' 6 48 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT")
  MENUID=$(eval $MENUCMD)
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

function Input() {
  TITLE="Input required"
  TEXT="$1"
  CMD=$(printf "%s --title '%s' --inputbox '%s' 24 48 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT")
  OUT=$(eval $CMD) || byebye 0
  echo $OUT
}

function SetBymeDeviceAddress() {
  DSTADDR=$(Input "Please, insert By-me device address (eg: 2005)")
  if [ -z $DSTADDR ]; then
    echo "ERROR: invalid address"
    byebye 1
  fi
  echo "DSTADDR=$DSTADDR"
}

function SetBymeFunctionalBlock() {
  TITLE="By-me device"
  MENUTEXT="Please, select By-me device blind actuator:"
  MENUITEMS="1 '01470.x (9in/8out)' on 2 '01471 (4out)' off 3 '01476 (blind module 2in 3out)' off 4 'Custom' off"
  MENUCMD=$(printf "%s --title '%s' --radiolist '%s' 24 48 15 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$MENUTEXT" "$MENUITEMS")
  DEVICEID=$(eval $MENUCMD)
  if [ $DEVICEID -eq 1 ]; then
    continue
  elif [ $DEVICEID -ge 2 ] && [ $DEVICEID -le 3 ]; then
    NotImplemented
    byebye 0
  elif [ $DEVICEID -eq 4 ]; then
    continue
  else
    byebye 0
  fi

  FBID=$(Input "Please, insert blind actuator functional-block index (eg: 25)")
  if [ -z $FBID ]; then
    echo "ERROR: invalid FB"
    byebye 1
  fi
  if ! [ "$FBID" -eq "$FBID" ] 2> /dev/null; then
    echo "ERROR: Sorry, integers only"
    byebye 1
  fi

  if [ $DEVICEID -eq 1 ]; then
    if [ $FBID -lt 22 ] || [ $FBID -gt 25 ]; then
      echo "ERROR: invalid FB value, correct values are 22, 23, 24 and 25"
      byebye 1
    fi

    TID=$(( $FBID - 22 ))
    RIDUP=$(( $TID*2 + 14 ))
    RIDDW=$(( $RIDUP+1 ))
    GOUP=$(( ($TID*2)*7 + 84 ))
    GODW=$(( $GOUP+7 ))
  fi

  if [ $DEVICEID -eq 4 ]; then
    RIDUP=$(Input "Please, insert Switch UP functional-block index (eg: 14)")
    RIDDW=$(Input "Please, insert Switch DOWN functional-block index (eg: 15)")
    GOUP=$(Input "Please, insert Switch UP communication-object index (eg: 84)")
    GODW=$(Input "Please, insert Switch DOWN communication-object index (eg: 91)")
  fi

  echo "FBID=$FBID"
  echo "TID=$TID"
  echo "RIDUP=$RIDUP"
  echo "RIDDW=$RIDDW"
  echo "GOUP=$GOUP"
  echo "GODW=$GODW"

}

function SelectBymeDevice() {
  SetBymeDeviceAddress
  SetBymeFunctionalBlock
}

function ChangeBymeConfiguration() {
  Ask "Are you sure to change By-me configuration?"

  if [ -z $DSTADDR ]; then SetBymeDeviceAddress; fi
  if [ -z $FBID ]; then SetBymeFunctionalBlock; fi

  Print "Reset AdjFB BLIND"
  SendMsg "BC $SRCADDR $DSTADDR 66 03D7  $(printf '%X\n' $FBID)  FF  1001  FF"
  sleep 0.1

  Print "Set new AdjFB SWITCH UP"
  SendMsg "BC $SRCADDR $DSTADDR 66 03D7  $(printf '%X\n' $RIDUP) FF  1001  00"
  sleep 0.1

  Print "Set new AdjFB SWITCH DOWN"
  SendMsg "BC $SRCADDR $DSTADDR 66 03D7  $(printf '%X\n' $RIDDW) FF  1001  00"
  sleep 0.1

  Print "Set GO link UP"
  SendMsg "BC $SRCADDR $DSTADDR 65 03E7  $(printf '%X\n' $GOUP)  00  9900 "
  sleep 0.1

  Print "Set GO link DOWN"
  SendMsg "BC $SRCADDR $DSTADDR 65 03E7  $(printf '%X\n' $GODW)  00  9901 "
  sleep 0.1

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

  Ask "Have you seen blind UP/DOWN movement ***two*** times?"

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

  Show "Now, please move the blind until bottom limit!"
  Print "Manual DOWN/UP until blind is closed"
  ManualMode

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

  while [ true ]; do
    TITLE="Command"
    MENUTEXT="Select:"
    MENUITEMS="1 'Move' 2 'Step'"
    MENUCMD=$(printf "%s --title '%s' --menu '%s' 24 48 15 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$MENUTEXT" "$MENUITEMS")
    MENUID=$(eval $MENUCMD)
    if [[ $MENUID == 1 ]]; then
      ManualModeMove
    elif [[ $MENUID == 2 ]]; then
      ManualModeStep
    else
      break
    fi
  done
}

function ManualModeMove() {

  while [ true ]; do
    SwitchUP 0
    SwitchDOWN 0

    TITLE="Command"
    MENUTEXT="Select:"
    MENUITEMS="1 'UP' 2 'DOWN'"
    MENUCMD=$(printf "%s --title '%s' --menu '%s' 24 48 15 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$MENUTEXT" "$MENUITEMS")
    MENUID=$(eval $MENUCMD)
    if [[ $MENUID == 1 ]]; then
      SwitchUP 1
    elif [[ $MENUID == 2 ]]; then
      SwitchDOWN 1
    else
      break
    fi

    TITLE="Command"
    TEXT="Press OK to to STOP movement"
    MENUCMD=$(printf "%s --title '%s' --msgbox '%s' 6 48 2>&1 1>&3" "$DIALOG" "$TITLE" "$TEXT")
    MENUID=$(eval $MENUCMD)
    EXIT=$?
  done
}

function ManualModeStep() {

  while [ true ]; do
    SwitchUP 0
    SwitchDOWN 0

    TITLE="Command"
    MENUTEXT="Select:"
    MENUITEMS="1 'Step UP' 2 'Step DOWN'"
    MENUCMD=$(printf "%s --title '%s' --menu '%s' 24 48 15 %s 2>&1 1>&3" "$DIALOG" "$TITLE" "$MENUTEXT" "$MENUITEMS")
    MENUID=$(eval $MENUCMD)
    if [[ $MENUID == 1 ]]; then
      SwitchUP 1
    elif [[ $MENUID == 2 ]]; then
      SwitchDOWN 1
    else
      break
    fi

    sleep 0.1
  done
}

function RestoreOriginalBymeConfiguration() {
  NotImplemented

  Ask "Are you sure to restore the By-me device to previous configuration?"

  if [ -z $DSTADDR ]; then SetBymeDeviceAddress; fi
  if [ -z $FBID ]; then SetBymeFunctionalBlock; fi

  Print "Remove GO link UP"
  SendMsg "BC $SRCADDR $DSTADDR 65 03E7  $(printf '%X\n' $GOUP)  02  9900 "
  sleep 0.1

  Print "Remove GO link DOWN"
  SendMsg "BC $SRCADDR $DSTADDR 65 03E7  $(printf '%X\n' $GODW)  02  9901 "
  sleep 0.1

  Print "Reset new AdjFB SWITCH UP"
  SendMsg "BC $SRCADDR $DSTADDR 66 03D7  $(printf '%X\n' $RIDUP) FF  1001  FF"
  sleep 0.1

  Print "Reset new AdjFB SWITCH DOWN"
  SendMsg "BC $SRCADDR $DSTADDR 66 03D7  $(printf '%X\n' $RIDDW) FF  1001  FF"
  sleep 0.1

  Print "Set AdjFB BLIND"
  SendMsg "BC $SRCADDR $DSTADDR 66 03D7  $(printf '%X\n' $FBID)  FF  1001  00"
  sleep 0.1

  Show "It works! I have changed By-me device configuration."

}


function DeleteBymeConfiguration() {
  Ask "Are you sure to restore to factory default the By-me device?"

  if [ -z $DSTADDR ]; then SetBymeDeviceAddress; fi

  SendMsg "BC $SRCADDR $DSTADDR 69 03D7  00  CC  4001  FFFFFFFF"

  Show "Ok, now you have to re-configure the By-me device on your plant.\nPlease do diagnostic on Vimar VIEW Pro APP."
}

############# MENU ITEM


I=0
MENUITEM[$I]="$I \"Select By-me device\""
ACTION[$I]="SelectBymeDevice"

let I++
MENUITEM[$I]="$I \"Change By-me configuration\""
ACTION[$I]="ChangeBymeConfiguration"

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
MENUITEM[$I]="$I \"Restore original By-me configuration\""
ACTION[$I]="RestoreOriginalBymeConfiguration"

let I++
MENUITEM[$I]="$I \"Delete By-me configuration\""
ACTION[$I]="DeleteBymeConfiguration"

let I++
MENUITEM[$I]="q QUIT"



################################################## MAIN

while [ 1 ]; do
  exec 3>&1
  CMD=$(menucmd "Actions" "Select action:" "${MENUITEM[*]}" $MENUID)
  MENUID=$(eval $CMD) || byebye 1
  if [[ $MENUID == "q" ]]; then
    byebye 1
  fi
  if [[ $MENUID -le 9 ]]; then
    RET=$(${ACTION[$MENUID]})
    if [[ $? != 0 ]]; then
      $DIALOG --title "Error" --msgbox "$RET" 10 40
    fi
    eval $RET
  fi
done

exit 0


