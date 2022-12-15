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

    // The number of data-cycles received in one second
    output reg[63:0] throughput,

    //========================  AXI Stream interface for the input side  ============================
    input[DATA_WIDTH-1:0]    AXIS_TDATA,
    input                    AXIS_TVALID,
    output reg               AXIS_TREADY,
    //===============================================================================================

    //========================  AXI Stream interface for AXI requests==  ============================
    output reg[71:0] AXI_REQ_TDATA,
    output reg       AXI_REQ_TVALID,
    input            AXI_REQ_TREADY
    //===============================================================================================
);

// This is the frequency of 'clk'
localparam CYCLES_PER_SECOND = 402832031;

// Counts the number of cycles that have occured where data is received
reg[7:0] data_cycle_counter;

// Counts down to zero when consecutive cycles don't have any received data
reg[31:0] idle_countdown;

// Counts the number of clock cycles up to CYCLES_PER_SEC
reg[31:0] clock_cycles;

// The number of bytes thus far transferred in the current second
reg[63:0] bytes_per_sec;


always @(posedge clk) begin

    if (clock_cycles == CYCLES_PER_SECOND) begin
        throughput    <= bytes_per_sec;
        bytes_per_sec <= 0;
        clock_cycles  <= 0;
    end else begin
        clock_cycles <= clock_cycles + 1;
    end

    // We're always ready to receive data
    AXIS_TREADY <= 1;

    // When this is raised, it strobes high for exactly one cycle
    AXI_REQ_TVALID <= 0;

    // When this is active, it will strobe high for exactly one cycle
    row_complete <= 0;

    // Any time we've been idle for too long, we force "data_cycle_counter" to zero
    if (idle_countdown)
        idle_countdown <= idle_countdown - 1;
    else
        data_cycle_counter <= 0;
    
    // If we are receiving data on this clock cycle...
    if (AXIS_TVALID & AXIS_TREADY) begin

        // If this cycle is an AXI read/write request...
        if (AXIS_TDATA[511:448] == 64'hBEADCAFEFADEDBAD) begin
            AXI_REQ_TDATA[31: 0] <= AXIS_TDATA[31: 0];  // Fill in the data-word in AXIS_TDATA
            AXI_REQ_TDATA[63:32] <= AXIS_TDATA[63:32];  // Fill in the AXI address in AXIS_TDATA
            AXI_REQ_TDATA[71:64] <= 0;                  // Assume this is an AXI write-request
            AXI_REQ_TVALID       <= 1;                  // Emit this AXI read/write request
        end else begin

            // Receiving data means we're no longer idle
            idle_countdown <= 400000000;

            // Keep track of how much data bas been transferred
            bytes_per_sec <= bytes_per_sec + 64;

            // If this is the 34th cycle, strobe "row_complete", and start counting
            // data cycles over again
            if (data_cycle_counter == 33) begin
                row_complete <= 1;
                data_cycle_counter <= 0;
            end
        
            // Otherwise, if this isn't the 34th cycle, just keep track of the
            // number of data-cycles that have occured
            else data_cycle_counter <= data_cycle_counter + 1;
        end
    end 

end


endmodule