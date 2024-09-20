/*
Version: 1.1
Variable_Flip_Selector.v

Author V1.0: Zeiler Randall-Reed
Author V1.1: Zeiler Randall-Reed

Description:
This module is where the break value counter and heuristic selector are combined. There is also an
included register to hold the break values for the first two cycles. This helps to ensure that all
of the data that is needed for the heuristic selector is available.

Notes:
- this module encapsulates the Break_Value_Counter and Heuristic_Selector modules, along with some
    additional logic and registers to handle control signals. 

Testing:
V1.0 : module in progress, no testing yet
    (8/16) : module draft complete, testbench in progress
V1.0 : module draft complete, no testing yet (8/18)
V1.1 : all tests passed (8/19)

*/

module Variable_Flip_Selector #(
    parameter MAX_CLAUSES_PER_VARIABLE = 20,
    parameter NSAT = 3,
    parameter P = 'h6E147AE0,
    localparam NSAT_BITS = $clog2(NSAT)
)(
    input clk_i,
    input rst_i,

    input [MAX_CLAUSES_PER_VARIABLE - 1 : 0] clause_broken_i,
    input [MAX_CLAUSES_PER_VARIABLE - 1 : 0] mask_bits_i,
    input [NSAT - 1 : 0]                     break_values_valid_i,
    input [31:0]                             random_i,

    input [NSAT_BITS - 1 : 0] wr_en_i,    // controller signal 
    // (all zeros = idle, 1 hot = write to respective bv reg, all ones = heurstic select)
    
    output reg [NSAT_BITS - 1 : 0]                selected_o,
    output reg [MAX_CLAUSES_PER_VARIABLE - 1 : 0] clause_valid_bits_o
);

    // localparams
    localparam MC = MAX_CLAUSES_PER_VARIABLE;
    localparam MCB = $clog2(MAX_CLAUSES_PER_VARIABLE);

    // integer vars
    integer i;

    // internal registers
    reg [MCB - 1 : 0] break_values_reg  [NSAT - 2 : 0];
    reg [MC  - 1 : 0] clause_valid_reg  [NSAT - 2 : 0];

    // internal wires
    wire [MCB - 1 : 0] break_value;
    wire [MC  - 1 : 0] clause_valid;

    wire [NSAT * MCB - 1 : 0] all_break_values;

    wire [NSAT_BITS - 1 : 0] select;

    genvar n;
    generate
        for(n = 0; n < NSAT - 1; n = n + 1) begin
            assign all_break_values[n * MCB +: MCB] = break_values_reg[n];
        end
        assign all_break_values[(NSAT - 1) * MCB +: MCB] = break_value;
    endgenerate

    // nice simple logic to check onehot
    wire control_one_hot = ~|(wr_en_i & (wr_en_i - 1)) & |wr_en_i;


    // initialize break_value_counter and heuristic_selector
    Break_Value_Counter #(
        .NUM_CLAUSES(MC),
        .NUM_ROWS(NSAT)
    ) bvc (
        .clause_broken_i(clause_broken_i),
        .mask_bits_i(mask_bits_i),
        .break_value_o(break_value),
        .clause_broken_o(clause_valid)
    );

    Heuristic_Selector #(
        .MAX_CLAUSES_PER_VARIABLE(MC),
        .NSAT(NSAT),
        .P(P)
    ) hs (
        .break_values_i(all_break_values),
        .break_values_valid_i(&wr_en_i ? break_values_valid_i : {NSAT{1'b0}}),
        .random_i(random_i),
        .enable_i(&wr_en_i),
        .select_o(select),
        .random_selection_o()
    );

    // break_values_reg and clause_valid_reg
    always @(posedge clk_i) begin
        if(rst_i) begin
            for(i = 0; i < NSAT - 1; i = i + 1) begin
                break_values_reg[i] <= 0;
                clause_valid_reg[i] <= 0;
            end
            selected_o <= 2'b11;
            clause_valid_bits_o <= 0;
        end else begin
            for(i = 0; i < NSAT - 1; i = i + 1) begin // assign break_values_reg if wr_en_i is one hot
                if(wr_en_i[i] == 1 && control_one_hot) begin
                    break_values_reg[i] <= break_value;
                    clause_valid_reg[i] <= clause_valid;
                end
            end
            if(&wr_en_i) begin // when we are using the data (all ones)
                // [NOTE]: removed the following line to pass lint, could be bug source
                // clause_valid_reg[NSAT - 1] <= clause_valid;
                selected_o <= select;
                clause_valid_bits_o <= select == 2'b10 ? clause_valid : clause_valid_reg[select];
            end
        end
    end

endmodule