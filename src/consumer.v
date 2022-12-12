//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 25-Oct-22  DWW  1000  Initial creation
//===================================================================================================


module axis_consumer#
(
    parameter DATA_WIDTH  = 512
) 
(
    input clk,
    output reg row_complete,


    //========================  AXI Stream interface for the input side  ============================
    input[DATA_WIDTH-1:0]    AXIS_TDATA,
    input                    AXIS_TVALID,
    output reg               AXIS_TREADY
    //===============================================================================================

);

// Counts the number of cycles that have occured where data is received
reg[7:0] data_cycle_counter;

// Counts down to zero when consecutive cycles don't have any received data
reg[31:0]idle_countdown;

always @(posedge clk) begin

    // We're always ready to receive data
    AXIS_TREADY <= 1;

    // When this is active, it will strobe high for exactly one cycle
    row_complete <= 0;

    // Any time we've been idle for too long, we force "data_cycle_counter" to zero
    if (idle_countdown)
        idle_countdown <= idle_countdown - 1;
    else
        data_cycle_counter <= 0;
    
    // If we are receiving data on this clock cycle...
    if (AXIS_TVALID & AXIS_TREADY) begin

        // Receiving data means we're no longer idle
        idle_countdown <= 400000000;
        
        // If this is the 66th cycle, strobe "row_complete", and start counting
        // data cycles over again
        if (data_cycle_counter == 65) begin
            row_complete <= 1;
            data_cycle_counter <= 0;
        end
        
        // Otherwise, if this isn't the 66th cycle, just keep track of the
        // number of data-cycles that have occured
        else data_cycle_counter <= data_cycle_counter + 1;
    end 

end


endmodule