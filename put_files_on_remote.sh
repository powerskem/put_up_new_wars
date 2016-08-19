#!/usr/bin/expect
set timeout "[expr 5*60]"

set username [lindex $argv 0]
set passwd [lindex $argv 1]
set hostname [lindex $argv 2]

if {[llength $argv] == 0} {
  send_user "Usage: scriptname username password hostname file1 \[file2\] ...\n"
  exit 1
}

#send_user "\n#####\n# $hostname\n#####\n"

spawn sftp $username@$hostname

expect {
  timeout { send_user "\nFailed to get password prompt\n"; exit 1 }
  eof { send_user "\nSSH failure for $hostname\n"; exit 1 }
  "*assword: "
}

send "$passwd\r"

expect {
  timeout { send_user "\nLogin failed. Password incorrect.\n"; exit 1 }
  "sftp> "
}

for {set i 3} {$i < [llength $argv]} {incr i 1} {
  set file [lindex $argv $i]

  send "put $file\r"

  expect {
    timeout { send_user "\nput failed\n"; exit 1 }
    "sftp> "
  }

}

send "bye\r"
send_user "\n"

close

