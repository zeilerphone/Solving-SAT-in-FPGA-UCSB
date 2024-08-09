/*
Version: 2.0
FIFO_Tree_tb.v

V0.0 Author: Dan Espinosa
V1.0 Author: Zeiler Randall-Reed
V2.0 Author: Zeiler Randall-Reed 

Description:
Testbench file for FIFO_Tree.v

Status: 
    V1.0 - Test passed
    V2.0 - Test in progress 

Change Log:
2024/08/05 - Zeiler Randall-Reed 
    Started V2.0
2024/08/06 - Zeiler Randall-Reed
    Added test plan and phase 1
    Having problems with the FIFO tree data being invalid so I'm going to try to test the buffer itself first.
*/

`timescale 1ns / 1ps
`define SIM
`define VERBOSE
`define ASSERT(CONDITION, MESSAGE) if ((CONDITION)==1'b1); else begin $error($sformatf MESSAGE); end

module FIFO_Tree_tb;

// Parameters for the FIFO tree
parameter CLAUSE_COUNT = 20;
parameter CLAUSE_WIDTH = 36;  
parameter BUFFER_DEPTH = 32;
// testing parameters
parameter NUM_TESTS = 1;
parameter TEST_CYCLES = 0.6 * CLAUSE_COUNT;

localparam CW = CLAUSE_WIDTH;
localparam CC = CLAUSE_COUNT;

localparam D_WORDS = (CC * CW) / 32;
localparam D_REM = (CC * CW) % 32;

// Inputs
reg clk = 1;
always #5 clk <= ~clk;
reg reset;

reg [CW * CC - 1 : 0] clauses_i; // 20*36 = 720
reg [CC - 1 : 0] clause_valid_i;
reg wren;
reg rden;
reg cOF;

// Output
wire empty;
wire OF;
wire [CW - 1 : 0] clause_o;

// Instantiate the Unit Under Test (UUT)
FIFO_tree #(
    .CLAUSE_COUNT(CC),
    .CLAUSE_WIDTH(CW),
    .BUFFER_DEPTH(BUFFER_DEPTH)
) uut (
    .clk(clk),
    .reset(reset),
    .clauses_i(clauses_i),
    .clause_valid_i(clause_valid_i),
    .wren(wren),
    .rden(rden),
    .cOF(cOF),
    .empty(empty),
    .OF(OF),
    .clause_o(clause_o)
);

// UUT internal signals
// wire [CW * 4 - 1 : 0] L0dout = uut.L0dout;
// wire [CW * 4 - 1 : 0] L0din = uut.L0din;
// wire [CW * 2 - 1 : 0] L1dout = uut.L1dout;
// wire [CW * 2 - 1 : 0] L1din = uut.L1din;
// wire [CW - 1 : 0] L2dout = uut.L2dout;
// wire [CW - 1 : 0] L2din = uut.L2din;

// internal data
reg [CW * CC - 1 : 0]   clauses         [NUM_TESTS-1:0];
reg [CC - 1 : 0]        valid_bits      [NUM_TESTS-1:0];
reg [CW     : 0]        valid_clauses_1 [CC-1:0];
integer num_valid;
integer matched, mismatched;
integer has_match;

// monitor signals
wire [3:0] uut_L0E, uut_L0F, uut_L0wren, uut_L0rden;
assign uut_L0E = uut.L0E;
assign uut_L0F = uut.L0F;
assign uut_L0wren = uut.L0wren;
assign uut_L0rden = uut.L0rden;
wire [CLAUSE_WIDTH * 4 - 1 : 0] uut_L0dout, uut_L0din;
assign uut_L0dout = uut.L0dout;
assign uut_L0din = uut.L0din;
wire [2:0] uut_L0src;
assign uut_L0src = uut.L0src;

wire [1:0] uut_L1E, uut_L1F, uut_L1rden, uut_L1wren;
assign uut_L1E = uut.L1E;
assign uut_L1F = uut.L1F;
assign uut_L1rden = uut.L1rden;
assign uut_L1wren = uut.L1wren;
wire [CLAUSE_WIDTH * 2 - 1 : 0] uut_L1dout, uut_L1din;
assign uut_L1dout = uut.L1dout;
assign uut_L1din = uut.L1din;
wire [1:0] uut_L1src;
assign uut_L1src = uut.L1src;

wire uut_L2E, uut_L2F, uut_L2rden, uut_L2wren;
assign uut_L2E = uut.L2E;
assign uut_L2F = uut.L2F;
assign uut_L2rden = uut.L2rden;
assign uut_L2wren = uut.L2wren;
wire [CLAUSE_WIDTH - 1 : 0] uut_L2dout, uut_L2din;
assign uut_L2dout = uut.L2dout;
assign uut_L2din = uut.L2din;
wire uut_L2src;
assign uut_L2src = uut.L2src;

wire uut_test_signal_1, uut_test_signal_2, uut_test_signal_3;
assign uut_test_signal_1 = uut.test_signal_1;
assign uut_test_signal_2 = uut.test_signal_2;
assign uut_test_signal_3 = uut.test_signal_3;

// temp signals 
reg [CC - 1 : 0]    temp_valid_reg;
integer             temp_valid_num;

// iterators
integer index, i, j, k;

/*
Test Plan:
    I want to test a few things:
    1. That the FIFO tree can store and retrieve data
    2. That the FIFO tree handles overflow correctly
    3. That the FIFO tree does First-In-First-Out (data ordering)

    Plan to use sequential tests to do this (i.e. there will be multiple phases to the test)

    [IN PROGRESS]
    Phase 1: Test that the FIFO tree can store and retrieve data 
        1. Load the FIFO tree with data and valid bits
        2. Read the data back out (over 12 cycles)
        3. Check that the data read out matches the data that was loaded in
        4. Repeat for multiple sets of data

    [TODO]
    Phase 2: Test that the FIFO tree handles overflow correctly
        need some way of overfilling the FIFO tree 
        I need a better idea of how it works to do that, so I'll come back to this
            maybe i can do this by setting all input clauses as valid for a couple cycles 
    Phase 3: Test that the FIFO tree does First-In-First-Out (data ordering)
        1. Load the FIFO tree with data and valid bits
        2. Load more data into the FIFO tree
        3. Read the data back out (over several cycles)
        4. make sure all the data from the first load is read out before the data from the second load
*/

initial begin
$display("FIFO Tree Testbench: Begin Simulation");
// generate test data using random number generation
$display("> Generating test data... ");
for(i = 0; i < NUM_TESTS; i = i + 1) begin
    temp_valid_reg = $random;
    temp_valid_num = 0;
    for(j = 0; j < CC; j = j + 1) begin
        for(k = 0; k < D_WORDS; k = k + 1) begin
            clauses[i][32 * k +: 32] = $random;
        end
        clauses[i][D_WORDS * 32 +: D_REM] = $random;
        if(temp_valid_reg[j] == 1) temp_valid_num = temp_valid_num + 1;
    end
    if(temp_valid_num > TEST_CYCLES) begin 
        temp_valid_reg = ~temp_valid_reg;
        temp_valid_num = CC - temp_valid_num;
    end
    valid_bits[i] = temp_valid_reg;
    $display("  * Test %d: %b, %d", i, temp_valid_reg, temp_valid_num);
end

// init regs to zero
for(i = 0; i < CC; i = i + 1) begin
    valid_clauses_1[i] = 0;
end

// Test Phase 1
$display("> Phase 1: Test that the FIFO tree can store and retrieve data");
    // initialize signals
    clauses_i = 0;
    clause_valid_i = 0;
    wren = 0;
    rden = 0;
    cOF = 0;

    // Reset the system
    reset = 1;
    @(negedge clk);
    @(negedge clk);
    reset = 0;

    // Test
    for(i = 0; i < NUM_TESTS; i = i + 1) begin
        matched = 0;
        mismatched = 0;
        num_valid = 0;
        // load correct data into valid_clauses_1
        for(j = 0; j < CC; j = j + 1) begin
            if(valid_bits[i][j] == 1) begin
                valid_clauses_1[num_valid][CW - 1 : 0] = clauses[i][CW * j +: CW];
                valid_clauses_1[num_valid][CW] = 1;
                num_valid = num_valid + 1;
            end
        end
        // load the FIFO tree with data
        clauses_i = clauses[i];
        clause_valid_i = valid_bits[i];
        wren = 1;
        // wait on data to sift to the bottom of the FIFO tree
        while(empty == 0) begin
            @(negedge clk);
            wren = 0;
        end
        rden = 1;
        for(j = 0; j < TEST_CYCLES; j = j + 1) begin
            @(negedge clk);
            has_match = 0;
            for(k = 0; k < CC; k = k + 1) begin
                if(valid_clauses_1[k][CW] == 1) begin
                    `ifdef VERBOSE
                    $display("  *>>> Test %d: Checking clause %d against %d", i, clause_o, valid_clauses_1[k][CW - 1 : 0]);
                    `endif
                    if(clause_o == valid_clauses_1[k][CW - 1 : 0]) begin
                        matched = matched + 1;
                        has_match = 1;
                        valid_clauses_1[k][CW] = 0;
                    end
                end
            end
            if(has_match == 0) begin
                mismatched = mismatched + 1;
                `ifdef VERBOSE
                $display("  * Test %d: Mismatched clause: %d", i, clause_o);
                `endif
            end
        end
        if(mismatched > 0) begin
            $display("  * Test %d: %d/%d clauses matched", i, matched, num_valid);
        end else begin
            $display("  * Test %d: All clauses matched", i);
        end
        
    end



$display("FIFO Tree Testbench: End Simulation");
$finish;

end

endmodule