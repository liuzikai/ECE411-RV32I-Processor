#!/bin/bash
# NOTE: PLEASE run this script with yes | ./collect_data.sh
# run at the ./mp4 directory
# parameter_list =''
testfile='mp4-cp3.s comp1.s comp2_i.s comp3.s'
# for paramater in $paramater_list
cp ./hdl/mp4.sv ./hdl/mp4_orig.sv 
# do
    mkdir ./log  # mkdir ./log_$parameter
    for file in $testfile
    do 
        # cp ./hdl/mp4_orig.sv ./hdl/mp4.sv
        # sed -i "s/[origina text]/[new text]/g" ./hdl/mp4.sv
        ./bin/rv_load_memory.sh ./testcode/$file
        cd ./simulation/modelsim/ 
        vsim -c -do mp4_run_msim_rtl_verilog.do > ../../log/$file.log
        cd ../..
        # post process the log file
        cd ./log
        # make sure we append the result
        echo "Data from running $file" >> data.log
        grep -i "Iteration: 1" $file.log >> data.log
        grep -i "[PerformanceCounter]" $file.log >> data.log
        cd ..
    done
# done
    
