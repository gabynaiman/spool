processes 10
env VAR_1: 1, VAR_2: 2
chdir '/tmp'
command 'tailf file.log'
pidfile '/tailf.pid'
restart_when { |p| p.memory > 512 }
