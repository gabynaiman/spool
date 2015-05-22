name 'SPOOL_TEST'
processes 1
command 'ruby -e "loop do; sleep 1; end"'
stop_signal :TERM