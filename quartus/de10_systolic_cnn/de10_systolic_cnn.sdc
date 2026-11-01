# DE10-Standard 50 MHz system clock.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# KEY[0] is asynchronous reset; SW inputs are synchronized in the top.
set_false_path -from [get_ports {KEY[0]}]
set_false_path -from [get_ports {SW[0]}]
set_false_path -from [get_ports {SW[1]}]
