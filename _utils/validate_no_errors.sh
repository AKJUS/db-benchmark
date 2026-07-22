# Known non-fatal log lines to ignore. Spark 4.1.x logs a spurious NPE from its background
# executor-heartbeater metrics thread (PartitionKeyedAccumulator.byPartition() returns null).
# It is logged by Utils.logUncaughtExceptions on a daemon thread; the query still succeeds and
# real job failures still surface as Python Py4JJavaError tracebacks, so these lines must not
# fail the check. Matches the three line shapes this NPE prints.
IGNORE='executor-heartbeater|PartitionKeyedAccumulator|logUncaughtExceptions'

if [ $(grep -iE 'error|exception' out/run_*.err | grep -v '\[ Warn' | grep -Ev "$IGNORE" | wc -l) = 0 ]
then
	# no true errors found, print last line of each output script
    echo "No Errors found in run_*.err logs"
else
	echo "The following errors have been found. Failing check"
	grep -iE "error|exception" out/*.err | grep -v '\[ Warn' | grep -Ev "$IGNORE"
	exit 1
fi



# check report generation. If this fails, the logs.csv/time.csv
# have errors 
Rscript _utils/parse_time_logs.R 2> report_check.txt
# https://gist.github.com/jesugmz/3fda0fc7c1006cedfe039ff1459c3174
output=$(wc -l report_check.txt | awk '{ print $1 }')
if [ $output -ne 0 ]
then
	echo "report check not empty"
	cat report_check.txt
	exit 1
fi
echo "time.csv and logs.csv can be parsed"



