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
    output reg lvds_data,

    // The megabytes-per-second of data received. 1 MB = 1,048,576 bytes
    output reg[31:0] mb_per_sec,

    //========================  AXI Stream interface for the input side  ============================
    input[DATA_WIDTH-1:0]    AXIS_IN_TDATA,
    input                    AXIS_IN_TVALID,
    output reg               AXIS_IN_TREADY,
    //===============================================================================================

    //========================  AXI Stream interface for AXI requests==  ============================
    output [71:0] AXI_REQ_TDATA,
    output reg    AXI_REQ_TVALID,
    input         AXI_REQ_TREADY
    //===============================================================================================
);

//===============================================================================================
// Field definitions for the TDATA lines
//===============================================================================================
wire[31:0] axi_addr_in  = AXIS_IN_TDATA[31:00];
wire[31:0] axi_data_in  = AXIS_IN_TDATA[63:32];
wire       axi_mode_in  = AXIS_IN_TDATA[64];

reg[31:0] axi_addr_out; assign AXI_REQ_TDATA[31:00] = axi_addr_out;
reg[31:0] axi_data_out; assign AXI_REQ_TDATA[63:32] = axi_data_out;
reg       axi_mode_out; assign AXI_REQ_TDATA[64   ] = axi_mode_out;
//===============================================================================================



// This is the frequency of 'clk'
localparam CYCLES_PER_SECOND = 402832031;

// If no stream data arrives in this many cycles, the state machine resets
localparam IDLE_TIMEOUT = 400000000;

// Counts the number of cycles that have occured where data is received
reg[7:0] data_cycle_counter;

// Counts down to zero when consecutive cycles haven't any received data
reg[31:0] idle_watchdog;

// Counts the number of clock cycles up to CYCLES_PER_SEC
reg[31:0] clock_cycles;

// The number of bytes thus far transferred in the current second
reg[63:0] bytes_per_sec;

// State of the consumer state machine
reg[1:0] csm_state;

always @(posedge clk) begin

    // We're always ready to receive data
    AXIS_IN_TREADY <= 1;

    // When this is raised, it strobes high for exactly one cycle
    AXI_REQ_TVALID <= 0;

    // When this is raised, it will strobe high for exactly one cycle
    row_complete <= 0;

    // This will be high on the first cycle after a data-row header is received
    lvds_data <= 0;

    // Count down the watchdog timer that tells how long since we've received row data
    if (idle_watchdog)
        idle_watchdog <= idle_watchdog - 1;
    else
        csm_state <= 0;

    case(csm_state)
        
        // Waiting for the first data-cycle of a packet
        0:  if (AXIS_IN_TVALID & AXIS_IN_TREADY) begin
         
                // If this cycle is an AXI read/write request...
                if (AXIS_IN_TDATA[511:448] == 64'hBEADCAFEFADEDBAD) begin
                    axi_data_out   <= axi_data_in;  // Fill in the data-word in AXIS_IN_TDATA
                    axi_addr_out   <= axi_addr_in;  // Fill in the AXI address in AXIS_IN_TDATA
                    axi_mode_out   <= axi_mode_in;  // Assume this is an AXI write-request
                    AXI_REQ_TVALID <= 1;            // Emit this AXI read/write request
                end

                else begin
                    
                    // This is the first data-cycle of a row of LVDS data
                    lvds_data <= 1;

                    // Receiving data means we're no longer idle
                    idle_watchdog <= IDLE_TIMEOUT;

                    // Next data-cycle is the first cycle of row-data
                    data_cycle_counter <= 1;

                    // Go wait for the rest of the data-packet to arrive
                    csm_state <= 1;
                end
            end
        
        // Here we're waiting for all the data-cycles containing row-data to arrive
        1:  if (AXIS_IN_TVALID & AXIS_IN_TREADY) begin
    
                // Accumulate a total of data-bytes received
                bytes_per_sec <= bytes_per_sec + 64;

                // The input stream isn't idle
                idle_watchdog <= IDLE_TIMEOUT;

                // If this is the 32nd data-cycle, it the last of the data for this row
                if (data_cycle_counter == 32) begin
                    csm_state <= 2;
                end 

                // Keep track of how many data-cycles we've recieved
                data_cycle_counter <= data_cycle_counter + 1;
            end

        // Here we're waiting for the row-trailer data-cycle
        2:  if (AXIS_IN_TVALID & AXIS_IN_TREADY) begin
                row_complete <= 1;
                csm_state    <= 0;
            end

    endcase

    // Once every second, compute the "megabytes per second" throughput rate
    if (clock_cycles == CYCLES_PER_SECOND) begin
        mb_per_sec    <= bytes_per_sec >> 20;
        bytes_per_sec <= 0;
        clock_cycles  <= 0;
    end else begin
        clock_cycles <= clock_cycles + 1;
    end

end


endmodule