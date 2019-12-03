#!/usr/bin/env bash

# Example Use: ./var_tf.sh "ec2profile=art cred_file=notart"
# used on string variables, not maps or lists

file=io.tf
m="= "

while
[[ $# -gt 0 ]]
do
  arr=($(echo $1 | tr "=" "\n"))
  j="= \"${arr[1]}\""
  sed -i -e "/${arr[0]}/{n;s/$m.*$/$j/;}" $file
  shift
done
