#!/bin/bash

QUICKSTACK_CFG=$1
USERNAME=admin
PASSWORD=redhat

if [ $QUICKSTACK_CFG"V" == "V" ]
then
  echo usage: configure_quickstack.sh quickstack.conf
  exit 1
fi

# Strip comments and empty lines from the config file
sed 's+#.*++g' $QUICKSTACK_CFG | grep -v '^\w*$' >> /tmp/quickstack.conf.$$

# While loop reads in the config file and runs hammer to set the variable.
while read line
do 
  PARAM=`echo $line | awk -F '=' '{print $1}' | awk -F '::' '{print $NF}'`
  CLASS=`echo $line | awk -F '=' '{print $1}' | sed "s+::$PARAM.*++g"`
  VALUE=`echo $line | awk -F '=' '{print $2}'`
  # Strip ' from VALUE
  VALUE=`echo $VALUE | sed "s+'++g"`
  PARAM_ID=`hammer -u ${USERNAME} -p ${PASSWORD} --output csv sc-param list --puppet-class=$CLASS --search $PARAM | grep $PARAM | awk -F, '{print $1}'`
  echo "Setting $PARAM to $VALUE on $CLASS, PARAM_ID = $PARAM_ID"
  
  if [ $PARAM_ID -ge 0 ]
  then
    hammer -u ${USERNAME} -p ${PASSWORD} sc-param update --id ${PARAM_ID} --override 1 --default-value "${VALUE}"
  else
    echo "Couldn't find parameter $PARAM"
  fi
 
done </tmp/quickstack.conf.$$

