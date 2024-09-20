/*
Version: 0.0
Controller.v

Author V0.0: Zeiler Randall-Reed

Description:
This module is the controller for the SAT solver. It is responsible for managing the control signals 
which the datapath sends to the rest of the modules. 
It sends the following signals:
    clause register write enable
    address translation table source
    variable table enable
    variable table write enable and address source mux select
    variable flip selector write enable
    clause negated literals buffer write enable
    temporal buffer wrapper write index
    fifo write enable
    fifo read enable
    unsat clause selector request

Change Log:
V0.0 
9/19/2024 - Zeiler Randall-Reed
    Created Controller.v
    Added simple counter that sends control signals to the datapath
*/
module Controller #(
    parameter CONTROLLER_SIGNAL_WIDTH = 13,
    parameter PIPELINE_DEPTH = 12
) (
    output reg [CONTROLLER_SIGNAL_WIDTH - 1 : 0] control_signal_o
);

    localparam COUNTER_WIDTH = $clog2(PIPELINE_DEPTH);

    reg [COUNTER_WIDTH - 1 : 0] counter;
    reg is_first_cycle;

    always @(posedge clk_i) begin
        if(rst_i) begin
            counter <= 4'b1011;
            is_first_cycle <= 1;
        end else begin
            if(counter == PIPELINE_DEPTH - 1) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
            if(is_first_cycle && counter == PIPELINE_DEPTH - 2) begin
                is_first_cycle <= 0;
            end
        end
    end

    always @(*) begin
        if(is_first_cycle) begin
            case(counter)
                4'b0000: control_signal_o <= 13'b0_00_0_0_00_1_11_0_0_0; // 1A
                4'b0001: control_signal_o <= 13'b0_01_0_0_00_0_11_0_0_0; // 1B  2A
                4'b0010: control_signal_o <= 13'b0_10_1_0_00_0_11_0_0_0; // 1C  2B  3A
                4'b0011: control_signal_o <= 13'b0_00_1_0_00_0_11_0_0_0; // 1D  2C  3B
                4'b0100: control_signal_o <= 13'b0_00_1_0_01_0_11_0_0_1; // 1E1 2D  3C
                4'b0101: control_signal_o <= 13'b0_00_0_0_10_0_00_0_0_0; // 1E2 2E1 3D  G1
                4'b0110: control_signal_o <= 13'b0_00_0_0_11_0_01_0_0_0; //     2E2 3E1 G2
                4'b0111: control_signal_o <= 13'b0_00_0_0_00_0_10_0_0_0; //         3E2 G3
                4'b1000: control_signal_o <= 13'b0_00_1_1_00_0_11_1_0_0; //             G4 F
                4'b1001: control_signal_o <= 13'b0_00_0_0_00_0_11_0_0_0; //             G5 F
                4'b1010: control_signal_o <= 13'b0_00_0_0_00_0_11_0_0_0; //             G6 F
                4'b1011: control_signal_o <= 13'b1_00_0_0_00_0_11_0_0_0; //             G7 F
            endcase
        end else begin
            case(counter)
                4'b0000: control_signal_o <= 13'b0_00_0_0_00_1_11_0_1_0; // 1A             F
                4'b0001: control_signal_o <= 13'b0_01_0_0_00_0_11_0_1_0; // 1B  2A         F
                4'b0010: control_signal_o <= 13'b0_10_1_0_00_0_11_0_1_0; // 1C  2B  3A     F
                4'b0011: control_signal_o <= 13'b0_00_1_0_00_0_11_0_1_0; // 1D  2C  3B     F
                4'b0100: control_signal_o <= 13'b0_00_1_0_01_0_11_0_1_1; // 1E1 2D  3C     F
                4'b0101: control_signal_o <= 13'b0_00_0_0_10_0_00_0_1_0; // 1E2 2E1 3D  G1 F
                4'b0110: control_signal_o <= 13'b0_00_0_0_11_0_01_0_1_0; //     2E2 3E1 G2 F
                4'b0111: control_signal_o <= 13'b0_00_0_0_00_0_10_0_1_0; //         3E2 G3 F
                4'b1000: control_signal_o <= 13'b0_00_1_1_00_0_11_1_1_0; //             G4 F
                4'b1001: control_signal_o <= 13'b0_00_0_0_00_0_11_0_1_0; //             G5 F
                4'b1010: control_signal_o <= 13'b0_00_0_0_00_0_11_0_1_0; //             G6 F
                4'b1011: control_signal_o <= 13'b1_00_0_0_00_0_11_0_1_0; //             G7 F
            endcase
        end
    end






endmodule
