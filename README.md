bedita-tools
============

Generic tools/scripts for BEdita


## be-newinstance.sh

Unix shell script for BEdita setup. Default branch used: "3-corylus"

Usage: be-newinstance.sh name [branch] [base-path] [unix-group-name]

 1. name: instance name (mandatory)
 1. branch: git branch for BEdita (default 3-corylus)
 1. base-path: base path fore new instance, will be created in base path/name (default /home/bedita3)
 1. unix-group-name: unix group name for permission on instance (default bedita)

## be3-perms.sh

Shell script to set write permissions to webserver user (like `www-data` or `apache`) to BE3 tmp and file related directories.

Backend /tmp and /files permissions are recursively changed using `setfacl` directive.
Frontends /tmp are also recursively changed

Usage: be3-perms.sh 
