# DE10-Standard 50 MHz system clock.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# KEY[0] is an asynchronous reset input.
# Reset assertion is asynchronous; release is synchronized internally.
set_false_path -from [get_ports {KEY[0]}]

# SW[0] and SW[1] are asynchronous physical switches.
# They feed only their first-stage input synchronizer registers.
set_false_path -from [get_ports {SW[0]}]
set_false_path -from [get_ports {SW[1]}]

# LED outputs drive human-visible indicators, not a synchronous
# external data interface with setup/hold timing requirements.
set_false_path -to [get_ports {LEDR[*]}]
