name 'Process pool'
processes 10
env VAR_1: 1, VAR_2: 2
dir '/tmp'
command 'tailf file.log'
pid_file '/tailf.pid'
restart_when { |p| p.memory > 512 }
stop_signal 'TERM'
kill_signal 'INT'
log_file 'test.log'
log_level 'INFO'
log_formatter { |s,d,p,m| "#{s},#{d},#{p},#{m}" }