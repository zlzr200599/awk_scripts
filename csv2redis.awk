#!/usr/bin/gawk -f
#
# script to output the rows from a csv file to Redis format. the idea is
# that the CSV data will be translated to a Hash structure in Redis and 
# inserted using the Redis HMSET command.
#
# the contained function formats the output according to the redis protocol.
#
# prerequisite is, that the CSV file has a header row. The header row names of
# the columns will be used as keys in redis. The header needs to use the same
# separator as is used in the data/rows. it is assumed that only one header row
# is present.
#
# you may pass a variable "separator" to the script to define the separator between
# the individual columns of the rows. the default separator is a comma.

# you may pass a variable "uidcolumn" to the script to define the column (number) 
# which is used as a unique id for the row. first column is number "1". the default
# is to use the record (row) number.
#
# you can pipe the resulting data directly to Redis, which will be very fast.
#
# example: 
#
#	awk -f csv2redis.awk csf_filename.csv
# or	awk -v separator="\t" -f csv2redis.awk csf_filename.csv
# or	awk -v separator="\t" -v uidcolumn=4 -f csv2redis.awk csv_filename.csv
# or	awk -v separator="\t" -f csv2redis.awk csf_filename.csv | redis-cli --pipe
#
#
# uwe.geercken@dweb.de
#
# last update: 2019-07-31
#
#

# function to construct the redis message according to the redis protocol
function toRedisProtocol(redisKey, recordUid, numberOfKeysAndValues, keys, values) 
{
    # redis command
    redisCommand="HMSET"
    # devider between the redis key and the UID of the record/row
    devider=":"
    # number of parts that will be sent to redis:
    # the HMSET command + the redis key + the number of header columns + the number of value columns
    numberOfParts= 1 + 1 + numberOfKeysAndValues
    # number of total parts of the command
    part1="*" numberOfParts "\r\n"
    # length of the redisCommand and the redisCommand itself
    part2="$" length(redisCommand) "\r\n" redisCommand "\r\n"
    # length of the redis key + length of the devider + length of the recordUid plus the constructed
    # key of redisKey + devider + recordUid
    part3="$" length(redisKey) + length(devider)+ length(recordUid) "\r\n" redisKey devider recordUid "\r\n"
    # intermediate result
    result = part1 part2 part3

    # the loop creates the appropriate output for each key and value pair (column) of the CSV file
    for(i=1;i<=numberOfValues;i++)
    {
    	result= result "$" length(keys[i]) "\r\n" keys[i] "\r\n"
	result= result "$" length(values[i]) "\r\n" values[i] "\r\n"
    }
    return result
} 

# begin of processing
BEGIN {
	# setting the field/column separator
	if(separator)
	{
		FS=separator
	}
	else
	{
		FS=",";
	}

	# the key to use for redis. the unique record key will be appended
	# to this redis key, so that it forms a unique identifier for the row.
	redisKey="test333"
	# which column (number) is used as the unique id for the row
	if(uidcolumn)
	{
		recordUidColumnNumber=uidcolumn
	}
}

# first row only
NR <= 1 {
	# split the header row into its individual fields
	numberOfKeys=split($0,keys,FS);
}

# all other rows
NR > 1 {
	# split the record into its individual values
	numberOfValues=split($0,values,FS)
	# the unique id of the record
	if(recordUidColumnNumber)
	{
		recordUid = values[recordUidColumnNumber]
	}
	else
	{
		recordUid = NR -1
	}
	# number of keys and values
	numberOfKeysAndValues = numberOfKeys + numberOfValues
	# create the redis command
	print toRedisProtocol(redisKey, recordUid, numberOfKeysAndValues, keys, values)
}


