verdiSetActWin -dock widgetDock_<Message>
sidCmdLineBehaviorAnalysisOpt -incr -clockSkew 0 -loopUnroll 0 -bboxEmptyModule 0  -cellModel 0 -bboxIgnoreProtected 0 
debImport "-f" "/home/host/Downloads/IC_Competiton_JJ/core/src/IDU/flist.f" \
          "-2001" "-top" "tb_IDU_pipe"
verdiSetActWin -dock widgetDock_<Message>
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
wvCreateWindow
verdiSetActWin -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvOpenFile -win $_nWave2 \
           {/home/host/Downloads/IC_Competiton_JJ/core/src/IDU/sim/idu_pipe_tb.fsdb}
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe/dut"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe/dut"
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_IDU_pipe/dut/clk} \
{/tb_IDU_pipe/dut/id_ex_alu_ctrl\[3:0\]} \
{/tb_IDU_pipe/dut/id_ex_rd\[4:0\]} \
{/tb_IDU_pipe/dut/id_ex_valid} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 )} 
wvSetPosition -win $_nWave2 {("G1" 4)}
wvGetSignalClose -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvZoomOut -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe/dut"
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_IDU_pipe/dut/clk} \
{/tb_IDU_pipe/dut/id_ex_alu_ctrl\[3:0\]} \
{/tb_IDU_pipe/dut/id_ex_rd\[4:0\]} \
{/tb_IDU_pipe/dut/id_ex_valid} \
{/tb_IDU_pipe/dut/ex_glb_flush} \
{/tb_IDU_pipe/dut/ex_id_ready} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 5 6 )} 
wvSetPosition -win $_nWave2 {("G1" 6)}
wvGetSignalClose -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe/dut"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe/dut"
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_IDU_pipe/dut/clk} \
{/tb_IDU_pipe/dut/id_ex_alu_ctrl\[3:0\]} \
{/tb_IDU_pipe/dut/id_ex_rd\[4:0\]} \
{/tb_IDU_pipe/dut/id_ex_valid} \
{/tb_IDU_pipe/dut/ex_glb_flush} \
{/tb_IDU_pipe/dut/ex_id_ready} \
{/tb_IDU_pipe/dut/if_id_instr\[31:0\]} \
{/tb_IDU_pipe/dut/if_id_instr_valid} \
{/tb_IDU_pipe/dut/if_id_pc\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 7 8 9 )} 
wvSetPosition -win $_nWave2 {("G1" 9)}
wvGetSignalClose -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G2" 0)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G2" 3)}
wvSetPosition -win $_nWave2 {("G2" 3)}
wvSetCursor -win $_nWave2 7128.753463 -snap {("G1" 6)}
wvSetCursor -win $_nWave2 44518.337950 -snap {("G1" 1)}
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe/dut"
wvGetSignalSetScope -win $_nWave2 "/tb_IDU_pipe/dut"
wvSetPosition -win $_nWave2 {("G2" 4)}
wvSetPosition -win $_nWave2 {("G2" 4)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_IDU_pipe/dut/clk} \
{/tb_IDU_pipe/dut/id_ex_alu_ctrl\[3:0\]} \
{/tb_IDU_pipe/dut/id_ex_rd\[4:0\]} \
{/tb_IDU_pipe/dut/id_ex_valid} \
{/tb_IDU_pipe/dut/ex_glb_flush} \
{/tb_IDU_pipe/dut/ex_id_ready} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
{/tb_IDU_pipe/dut/if_id_instr\[31:0\]} \
{/tb_IDU_pipe/dut/if_id_instr_valid} \
{/tb_IDU_pipe/dut/if_id_pc\[31:0\]} \
{/tb_IDU_pipe/dut/id_ex_pc\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G3" \
}
wvSelectSignal -win $_nWave2 {( "G2" 4 )} 
wvSetPosition -win $_nWave2 {("G2" 4)}
wvGetSignalClose -win $_nWave2
wvSetPosition -win $_nWave2 {("G2" 3)}
wvSetPosition -win $_nWave2 {("G2" 2)}
wvSetPosition -win $_nWave2 {("G2" 1)}
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G2" 1)}
wvSetPosition -win $_nWave2 {("G2" 2)}
wvSetPosition -win $_nWave2 {("G2" 3)}
wvSetPosition -win $_nWave2 {("G2" 4)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G2" 4)}
wvSetCursor -win $_nWave2 46045.927978 -snap {("G1" 0)}
wvSetCursor -win $_nWave2 51574.349030 -snap {("G1" 1)}
wvSetCursor -win $_nWave2 44736.565097 -snap {("G1" 1)}
