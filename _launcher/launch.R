library("data.table")
if (!packageVersion("data.table") >= "1.13.0")
  stop("db-benchmark launcher script depends on recent data.table features, install at least 1.13.0.")
source("./_launcher/launcher.R")

.nodename = Sys.info()[["nodename"]]
mockup = as.logical(Sys.getenv("MOCKUP", "false"))

run_tasks = getenv("RUN_TASKS") # run_tasks = c("groupby","join")
if (!length(run_tasks)) {
  cat("No benchmark tasks to run\n")
  q("no")
}
run_solutions = getenv("RUN_SOLUTIONS") # run_solutions = c("data.table","dplyr","pydatatable","spark","pandas")
if (!length(run_solutions)) {
  cat("No benchmark solutions to run\n")
  q("no")
}

data = fread("./_control/data.csv", logical01=TRUE, colClasses=c("character","character","character","character","character","character","logical"))
if (anyDuplicated(data[["data"]]))
  stop("_control/data.csv contains duplicated data cases")
data[active==TRUE, # filter on active datasets
     ][run_tasks, on="task", nomatch=NA # filter for env var RUN_TASKS
       ][, c("active") := NULL # remove unused
         ][] -> data
if (any(is.na(data$data))) stop("missing entries in ./_control/data.csv for some tasks")

timeout = fread("./_control/timeout.csv", colClasses=c("character","character","numeric"))
timeout[run_tasks, on="task", nomatch=NA #  # filter for env var RUN_TASKS
        ] -> timeout
if (any(is.na(timeout$minutes))) stop("missing entries in ./_control/timeout.csv for some tasks")

solution = fread("./_control/solutions.csv")
solution[run_solutions, on="solution", nomatch=NA # filter for env var RUN_SOLUTIONS
         ] -> solution
if (any(is.na(solution$task))) stop("missing entries in ./_control/solutions.csv for some solutions")

# what to run, log machine name, lookup timeout
dt = solution[data, on="task", allow.cartesian=TRUE, nomatch=NULL]
dt[, "nodename" := .nodename]
dt[, "in_rows" := sapply(strsplit(data, split="_", fixed=TRUE), `[[`, 2L)]
stopifnot(dt$in_rows == dt$nrow)
dt[timeout, "timeout_s" := i.minutes*60, on=c("task","in_rows")]
if (any(is.na(dt$timeout_s))) stop("missing entries in ./_control/timeout.csv for some tasks, detected after joining to solutions and data to run")

# detect if script has been already run before for currently installed version/revision
lookup_run_batch(dt)

machine_type = getenv("MACHINE_TYPE")
dt[,machine_type := machine_type]

skipped_benchmarks = fread("./_control/skipped_benchmarks.csv", logical01=TRUE, colClasses=c("character","character","character","character"))
print("skipping benchmarks defined in _control/skipped_benchmarks.csv")
print(skipped_benchmarks)

dt = dt[!skipped_benchmarks, on = c("solution", "task", "data", "machine_type")]

# print list of solutions that are going to be run in this batch so we know upfront which will be skipped
cat("Benchmark solutions to run: ", dt[is.na(run_batch), paste(unique(solution),collapse=", ")], "\n", sep="")

is.stop()
is.pause()
is.stop()

# launch script, if not mockup, if not already run, unless forcerun
dt
launch(dt, mockup=mockup)

# terminates
q("no")
