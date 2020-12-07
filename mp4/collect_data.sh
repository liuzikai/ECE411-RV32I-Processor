#!/bin/bash
# NOTE: PLEASE run this script with yes | ./collect_data.sh
# run at the ./mp4 directory

testfile='mp4-cp3.s comp1.s comp2_i.s comp3.s'
l2_d_cache_s_index='9 6'
l2_d_cache_way_deg='3 2'
l2_i_cache_switch='1 0'
# for paramater in $paramater_list
cp ./hvl/top.sv ./hvl/top_orig.sv 
mkdir ./log
# first build the directory 
for l2_i_switch in $l2_i_cache_switch; # whether the L2 instruction cache is used or not
do
    for l2_d_s_idx in $l2_d_cache_s_index; # value of the L2 s index 
    do
        for l2_d_way in $l2_d_cache_way_deg; # value of way
        do
            cd ./log
            mkdir ./l2_i_cache_${l2_i_switch}
            cd ./l2_i_cache_${l2_i_switch}
            mkdir ./l2_d_s_idx_${l2_d_s_idx}
            cd ./l2_d_s_idx_${l2_d_s_idx}
            mkdir ./l2_d_way_${l2_d_way}  
            cd ../../../  # go back to mp4 directory
        done
    done
done

for l2_i_switch in $l2_i_cache_switch; # whether the L2 instruction cache is used or not
do
    cp ./hvl/top_orig.sv ./hvl/top.sv
    sed -i "s/define USE_L2_I_CACHE      1/define USE_L2_I_CACHE      $l2_i_switch/g" ./hvl/top.sv
    for l2_d_s_idx in $l2_d_cache_s_index; # value of the L2 s index 
    do
        sed -i "s/define L2_D_CACHE_S_INDEX  9/define L2_D_CACHE_S_INDEX  $l2_d_s_idx/g" ./hvl/top.sv
        for l2_d_way in $l2_d_cache_way_deg; # value of way
        do
            sed -i "s/define L2_D_CACHE_WAY_DEG  3/define L2_D_CACHE_WAY_DEG  $l2_d_way/g" ./hvl/top.sv
            for file in $testfile
            do 
                # cp ./hvl/top_orig.sv ./hvl/top.sv
                # sed -i "s/`define USE_L2_I_CACHE      1/`define USE_L2_I_CACHE      0/g" ./hvl/top.sv
                # sed -i "s/`define USE_I_PREFETCHER    1/`define USE_I_PREFETCHER    0/g" ./hvl/top.sv
                # sed -i "s/`define USE_L2_D_CACHE      1/`define USE_L2_D_CACHE      0/g" ./hvl/top.sv
                ./bin/rv_load_memory.sh ./testcode/$file
                cd ./simulation/modelsim/ 
                vsim -c -do mp4_run_msim_rtl_verilog.do > ../../log/l2_i_cache_${l2_i_switch}/l2_d_s_idx_${l2_d_s_idx}/l2_d_way_${l2_d_way}/$file.log
                cd ../..
                # post process the log file
                cd ./log/l2_i_cache_${l2_i_switch}/l2_d_s_idx_${l2_d_s_idx}/l2_d_way_${l2_d_way}
                # make sure we append the result
                # echo "Data from running $file"
                echo "Data from running $file" >> data.log
                echo "Data from running $file" >> time.log
                grep -i "Iteration: 1" $file.log >> time.log
                grep -i "Iteration: 1" $file.log >> data.log
                grep -i "PerformanceCounter" $file.log >> data.log
                # pwd
                cd ../../../..
                # pwd
            done
        done
    done
done
    
