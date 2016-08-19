################
put_up_new_wars.tar
################

Put these files in $folder:
put_up_new_wars.sh
new_war.sh
delete_folders_on_remote.sh
put_files_on_remote.sh

Ensure they are all executable.

Put the new war files in $folder.

cd to $folder

Call the script:
./put_up_new_wars.sh [OPTIONS] file1.war file2.war ...

The program will:
- ftp the named war files to the remote host
- ftp the working script (new_war.sh) to the remote host
- stop the tomcat server on the remote host
- back up *ALL* war files in the webapps folder on the remote host
- delete the apache-tomcat/work directory on the remote host
- delete the webapps folders for the named war files on the remote host
- put the named war files into the webapps folder on the remote host
- restart the tomcat server on the remote host
- ftp the backup*.tar file(s) from the remote host to local $folder
- delete the backup*.tar file(s) from the remote host
- delete the working script (new_war.sh) from the remote host
