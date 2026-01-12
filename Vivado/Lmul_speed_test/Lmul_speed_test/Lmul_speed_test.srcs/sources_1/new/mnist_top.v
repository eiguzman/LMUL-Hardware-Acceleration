`timescale 1ns / 1ps
module mnist_top #(
    parameter N = 28,
    parameter M = 10,            // 10 classes for MNIST
    parameter BF16_WIDTH = 16
)(
    input  wire clk,
    input  wire rstn,
    input  wire start,          // Start inference
    input  wire [N*N*BF16_WIDTH-1:0] image_input,    // Input image
    input  wire [M*28*28*BF16_WIDTH-1:0] weight_input, // Fully connected layer weights
    output reg  [3:0] predicted_label,   // 4 bits for class label 0-9
    output reg  done
);

    // Internal signals
    reg systolic_start;
    wire systolic_done;
    wire [M*BF16_WIDTH-1:0] output_activations;

    // Instantiate systolic array
    systolic #(
        .N(N),
        .M(M),
        .BF16_WIDTH(BF16_WIDTH)
    ) systolic_inst (
        .clk(clk),
        .rstn(rstn),
        .start(systolic_start),
        .input_image(image_input),
        .weights(weight_input),
        .output_activations(output_activations),
        .done(systolic_done)
    );

    // Control FSM
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        COMPUTE,
        RESULT
    } fsm_state_t;

    fsm_state_t state, next_state;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            done <= 0;
            predicted_label <= 0;
        end else begin
            state <= next_state;
            if (state == RESULT) begin
                // Decode max activation
                predicted_label <= decode_max(output_activations);
                done <= 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = COMPUTE;
            COMPUTE: next_state = systolic_done ? RESULT : COMPUTE;
            RESULT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Control signals
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            systolic_start <= 0;
        end else if (state == LOAD) begin
            systolic_start <= 1;
        end else begin
            systolic_start <= 0;
        end
    end

    // Function to decode max activation index
    function [3:0] decode_max(input [M*BF16_WIDTH-1:0] activations);
        integer i;
        real max_val;
        integer max_idx;
        begin
            max_val = -1e9;
            max_idx = 0;
            for (i=0; i<M; i=i+1) begin
                real val = $bitstoreal(activations[(i+1)*BF16_WIDTH-1 -: BF16_WIDTH]);
                if (val > max_val) begin
                    max_val = val;
                    max_idx = i;
                end
            end
            decode_max = max_idx[3:0];
        end
    endfunction

endmodule
