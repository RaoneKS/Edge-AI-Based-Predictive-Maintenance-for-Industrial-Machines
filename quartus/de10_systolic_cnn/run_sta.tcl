# TimeQuest reports for the post-fit DE10 systolic CNN.
# Run with: quartus_sta -t run_sta.tcl -c de10_systolic_cnn
package require ::quartus::project
package require ::quartus::sta

project_open -revision de10_systolic_cnn de10_systolic_cnn
file mkdir output_files/sta_reports

# Slow timing model: setup analysis.
create_timing_netlist -model slow
read_sdc
update_timing_netlist
report_clocks -summary -file output_files/sta_reports/clocks_slow.txt
check_timing -file output_files/sta_reports/check_timing_slow.txt
report_timing -setup -npaths 20 -detail full_path -file output_files/sta_reports/setup_slow.txt
delete_timing_netlist

# Fast timing model: hold analysis.
create_timing_netlist -model fast
read_sdc
update_timing_netlist
report_clocks -summary -file output_files/sta_reports/clocks_fast.txt
check_timing -file output_files/sta_reports/check_timing_fast.txt
report_timing -hold -npaths 20 -detail full_path -file output_files/sta_reports/hold_fast.txt
delete_timing_netlist

project_close
puts "TIMEQUEST_REPORTS_COMPLETE"
