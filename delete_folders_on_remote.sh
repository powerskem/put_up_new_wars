#!/usr/bin/expect
set timeout 9

set username [lindex $argv 0]
set passwd [lindex $argv 1]
set hostname [lindex $argv 2]

if {[llength $argv] < 4} {
  send_user "Usage: scriptname username password hostname folder1 \[ folder2 ... \]\n"
  exit 1
}

#send_user "\n#####\n# $hostname\n#####\n"

spawn ssh $username@$hostname

expect {
  timeout { send_user "\nFailed to get password prompt\n"; exit 1 }
  eof { send_user "\nSSH failure for $hostname\n"; exit 1 }
  "*assword: "
}

send "$passwd\r"

expect {
  timeout { send_user "\nLogin failed. Password incorrect.\n"; exit 1 }
  "*\$ "
}

# Do the first sudo rm -rf $dir ... It requires a password
  set i 3
  set dir [lindex $argv $i]

  #TODO Check to see if the folder exists first
  send "sudo rm -rf $dir\r"

  expect {
    timeout { send_user "\nsudo failed\n"; exit 1 }
    "*?password for ${username}: "
  }

  send "$passwd\r"

  expect {
    timeout { send_user "\nLogin failed. Password incorrect.\n"; exit 1 }
    "*\$ "
  }

# Do the remaining sudo rm -rf $dir ... No password required.
for {set i 4} {$i < [llength $argv]} {incr i 1} {
  set file [lindex $argv $i]

  #TODO Check to see if the folder exists first
  send "sudo rm -rf $dir\r"

  expect {
    timeout { send_user "\nLogin failed. Password incorrect.\n"; exit 1 }
    "*\$ "
  }

}

send "exit\r"
send_user "\n"
close

