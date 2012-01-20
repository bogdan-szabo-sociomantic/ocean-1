# ------------------------------------------------------------------------------
# Connects to a set of servers using ssh, with each ssh session opened in a
# separate pane, using tmux.
#
# Script usage
#     tmuxconnect.sh $session $pre $post $servers
# where:
#     $session  = name of tmux session to create
#     $location = location of servers (eu / us)
#     $servers  = list of server numbers to connect to
#
# Server names are formed by iterating over the $servers list and inserting the
# number in the appropriate string. So, for example, if $servers = 1 4 7, and
# $location = eu, the following servers will be connected to:
#     root@eq6-1.sociomantic.com
#     root@eq6-4.sociomantic.com
#     root@eq6-7.sociomantic.com


# ------------------------------------------------------------------------------
# Parse script arguments

i=0
session=''
location=''
servers=''

for arg in $@
do
      if [ $i -eq 0 ]; then session=$arg;
    elif [ $i -eq 1 ]; then location=$arg;
    else                    servers="$servers $arg";
    fi

    i=$((i+1))
done

srv_suffix='.sociomantic.com'
  if [ $location = "eu" ]; then srv_prefix='root@eq6-';
elif [ $location = "us" ]; then srv_prefix='root@is-';
else                            echo "location must be one of {eu, us}"; exit 1;
fi


# ------------------------------------------------------------------------------
# Check that tmux session isn't already running

running=`tmux list-sessions 2>/dev/null | grep $session | wc -l`

if [ $running -ne 0 ]; then echo "tmux session $session is already running"; exit 1;
fi


# ------------------------------------------------------------------------------
# Form commands string

cmd=''
i=0
for server in $servers
do
    if   [ $i -eq 0 ]; then
        cmd="$cmd tmux new-session -d -s $session;";
        cmd="$cmd tmux new-window 'ssh $srv_prefix$server$srv_suffix';";
    else
        cmd="$cmd tmux split-window 'ssh $srv_prefix$server$srv_suffix';";
        cmd="$cmd tmux select-layout even-vertical;";
    fi

    i=$((i+1))
done

cmd="$cmd tmux -2 attach-session -d"


# ------------------------------------------------------------------------------
# Execute commands

#echo $cmd
eval $cmd

