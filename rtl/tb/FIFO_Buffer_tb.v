/*
Version: 1.0
FIFO_Buffer_tb.v

V1.0 Author: Zeiler Randall-Reed

Description:
Testbench file for FIFO_Buffer.v
This file was created to test the FIFO buffer due to invalid signals during the FIFO tree testing

Status: 
    V1.0 - Incomplete

*/

`timescale 1ns / 1ps
`define SIM
`define VERBOSE

module FIFO_Buffer_tb;

// Parameters for the FIFO buffer
parameter DATA_WIDTH = 36;
parameter BUFFER_DEPTH = 32;
parameter BUFFER_ADDR_WIDTH = $clog2(BUFFER_DEPTH);
// testing parameters
parameter NUM_TESTS = 5;
parameter TEST_CYCLES = 3;

localparam DW = DATA_WIDTH;
localparam BA = BUFFER_ADDR_WIDTH;

localparam D_WORDS = DW / 32;
localparam D_REM = DW % 32;

// Inputs
reg clk = 1;
always #5 clk <= ~clk;
reg reset;

reg [DW-1:0] data_i;
reg rden_i;
reg wren_i;

// Output
wire [DW-1:0] data_o;
wire empty_o;
wire full_o;

// Instantiate the Unit Under Test (UUT)
FIFO_Buffer #(
    .DATA_WIDTH(DW),
    .BUFFER_ADDR_WIDTH(BA)
) uut (
    .clk(clk),
    .reset(reset),
    .data_i(data_i),
    .rden_i(rden_i),
    .wren_i(wren_i),
    .data_o(data_o),
    .empty_o(empty_o),
    .full_o(full_o)
);

// internal data
reg [DW - 1 : 0] data [TEST_CYCLES - 1 : 0] [NUM_TESTS - 1 : 0];
integer matched;
reg phase1_pass, phase2_pass;


// iterators
integer i, j, k;

initial begin
$display("FIFO Buffer Testbench: Begin Simulations");
// generate test data
$display("> Generating test data...");
for (i = 0; i < NUM_TESTS; i = i + 1) begin
    for (j = 0; j < TEST_CYCLES; j = j + 1) begin
        for(k = 0; k < D_WORDS; k = k + 1) begin
            data[j][i][k*32 +: 32] = $random;
        end
        data[j][i][D_WORDS*32 +: D_REM] = $random;
        $display("  * Test %0d, Cycle %0d: Data = %0h", i, j, data[j][i]);
    end
end 
phase1_pass = 1;
phase2_pass = 1;
    
// run tests
$display("> Phase 1: Test that the FIFO buffer can write and read data");
    // initialize signals
    data_i = 0;
    rden_i = 0;
    wren_i = 0;
    // reset the system
    reset = 1;
    @(negedge clk);
    @(negedge clk);
    reset = 0;
    // test
    for (i = 0; i < NUM_TESTS; i = i + 1) begin
        matched = 0;
        for(j = 0; j < TEST_CYCLES; j = j + 1) begin
            // write data
            data_i = data[j][i];
            wren_i = 1;
            @(negedge clk);
            wren_i = 0;
            // read data
            rden_i = 1;
            @(negedge clk);
            rden_i = 0;
            // check data
            if (data_o == data[j][i]) begin
                matched = matched + 1;
            end 
            `ifdef VERBOSE
            if (data_o == data[j][i]) begin
                $display("  *** Test %0d, Cycle %0d: Data Matched", i, j);
            end else begin
                $display("  *** Test %0d, Cycle %0d: Data Mismatch", i, j);
                $display("      Expected: %0h, Actual: %0h", data[j][i], data_o);
            end
            `endif
        end
        if (matched == TEST_CYCLES) begin
            $display("  * Test %0d: PASSED", i);
        end else begin
            $display("  * Test %0d: FAILED", i);
            phase1_pass = 0;
        end
        @(negedge clk);
    end

$display("> Phase 2: Test that sequential writes and reads are okay");
    // initialize signals
    data_i = 0;
    rden_i = 0;
    wren_i = 0;
    // reset the system
    reset = 1;
    @(negedge clk);
    @(negedge clk);
    reset = 0;
    // test
    for (i = 0; i < NUM_TESTS; i = i + 1) begin
        matched = 0;
        wren_i = 1;
        for(j = 0; j < TEST_CYCLES; j = j + 1) begin
            // write data
            data_i = data[j][i];
            @(negedge clk);
        end
        wren_i = 0;
        rden_i = 1;
        @(negedge clk);
        for(j = 0; j < TEST_CYCLES; j = j + 1) begin
            // read data
            if(data_o == data[j][i]) begin
                matched = matched + 1;
            end
            `ifdef VERBOSE
            if (data_o == data[j][i]) begin
                $display("  *** Test %0d, Cycle %0d: Data Matched", i, j);
            end else begin
                $display("  *** Test %0d, Cycle %0d: Data Mismatch", i, j);
                $display("      Expected: %0h, Actual: %0h", data[j][i], data_o);
            end
            `endif
            @(negedge clk);
        end
        rden_i = 0;
        if (matched == TEST_CYCLES) begin
            $display("  * Test %0d: PASSED", i);
        end else begin
            $display("  * Test %0d: FAILED", i);
            phase2_pass = 0;
        end
        @(negedge clk);
    end
    $display("Results:");
    if (phase1_pass == 1) begin
        $display("  Phase 1: PASSED");
    end else begin
        $display("  Phase 1: FAILED");
    end
    if (phase2_pass == 1) begin
        $display("  Phase 2: PASSED");
    end else begin
        $display("  Phase 2: FAILED");
    end
    
$display("FIFO Buffer Testbench: End Simulations");
$finish;

end

endmodule