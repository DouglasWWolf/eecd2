//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// This module watched input strobes and uses them to report events on an AXI stream bus
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 25-Dec-22  DWW  1000  Initial creation
//===================================================================================================


module event_reporter #
(
    parameter DATA_WIDTH  = 256
) 
(
    input clk, resetn,

    input report_underflow,

    //========================  AXI Stream interface for the output side  ===========================
    output reg[DATA_WIDTH-1:0]  AXIS_OUT_TDATA,
    output reg                  AXIS_OUT_TVALID,
    input                       AXIS_OUT_TREADY
    //===============================================================================================
);

reg fsm_state;

localparam MESSAGE_TYPE = 1;
localparam EVENT_TYPE   = 1;

always @(posedge clk) begin
    
    if (resetn == 0) begin
        fsm_state       <= 0;
        AXIS_OUT_TVALID <= 0;
    end else case (fsm_state)

        0:  if (report_underflow) begin
                AXIS_OUT_TDATA          <= 0;
                AXIS_OUT_TDATA[255:248] <= MESSAGE_TYPE;
                AXIS_OUT_TDATA[7:0]     <= EVENT_TYPE;
                AXIS_OUT_TVALID         <= 1;
                fsm_state               <= 1;
            end

        1:  if (AXIS_OUT_TREADY & AXIS_OUT_TVALID) begin
                AXIS_OUT_TVALID <= 0;
                fsm_state       <= 0;
            end
    endcase

end


endmodule
