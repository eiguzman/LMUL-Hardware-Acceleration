`timescale 1ns/1ps

module systolic #(
    parameter N = 28,             // Input image size (28x28)
    parameter M = 128,            // Number of output neurons
    parameter BF16_WIDTH = 16
)(
    input  wire                         clk,
    input  wire                         rstn,
    input  wire                         start,
    input  wire [N*N*BF16_WIDTH-1:0]    input_image,     // Flattened input image
    input  wire [M*N*BF16_WIDTH-1:0]    weights,         // Flattened weights matrix
    output reg  [M*BF16_WIDTH-1:0]      output_activations, // Final output vector
    output reg                          done
);

    // Internal parameters
    localparam NUM_INPUTS = N * N; // Total input pixels

    // Internal signals
    reg [N*N*BF16_WIDTH-1:0] input_buffer; // For streaming input
    reg [M*N*BF16_WIDTH-1:0] weight_buffer; // For storing weights

    // FSM states
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        COMPUTE,
        DONE
    } state_t;

    state_t state, next_state;

    // Counters
    integer col_idx; // Column (neuron index)
    integer row_idx; // Row (pixel index)
    integer cycle_counter;

    // Data registers
    reg [BF16_WIDTH-1:0] input_data [0:N*N-1];   // Input pixels
    reg [BF16_WIDTH-1:0] weight_data [0:M-1][0:N-1]; // Weights per neuron
    reg [BF16_WIDTH-1:0] partial_sum [0:M-1];    // Accumulated sums

    // Instantiate PEs: We will create a 1D array of M PEs for parallel output
    // Each PE computes dot product for one neuron
    genvar m_idx;
    generate
        for (m_idx = 0; m_idx < M; m_idx = m_idx + 1) begin : PE_ARRAY
            // Each PE has a pipeline of N multiply-accumulate PEs
            // For simplicity, we implement pipelined chain here
            wire [BF16_WIDTH-1:0] sum_out;
            wire valid_out;

            // Pipeline registers for chain
            wire [BF16_WIDTH-1:0] partial_products [0:N-1];

            // Generate the chain
            // First stage: multiply input pixel with weight
            for (genvar n_idx = 0; n_idx < N; n_idx = n_idx + 1) begin : PIPELINE_STAGES
                // Compute index
                localparam integer pixel_idx = n_idx;

                // Input pixel
                wire [BF16_WIDTH-1:0] in_pixel = input_data[pixel_idx];

                // Weight for this neuron and pixel
                wire [BF16_WIDTH-1:0] weight_val = weight_data[m_idx][pixel_idx];

                // Instantiate lmul_bf16
                wire [BF16_WIDTH-1:0] prod;
                wire prod_valid;

                lmul_bf16 #(.E_BITS(8), .M_BITS(7), .EM_BITS(15), .BITW(16))
                mult_inst (
                    .clk(clk),
                    .rstn(rstn),
                    .i_a(in_pixel),
                    .i_b(weight_val),
                    .o_p(prod)
                );

                // Store product
                assign partial_products[n_idx] = prod;
            end

            // Accumulate products across N stages
            reg [BF16_WIDTH-1:0] acc;
            integer n;

            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    acc <= {BF16_WIDTH{1'b0}};
                end else if (state == COMPUTE) begin
                    acc <= {BF16_WIDTH{1'b0}};
                    for (n = 0; n < N; n = n + 1) begin
                        acc <= acc + partial_products[n]; // Note: '+' needs BF16 support; for now, assume operator exists
                    end
                end
            end

            assign sum_out = acc;

            // Final output for each neuron
            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    partial_sum[m_idx] <= {BF16_WIDTH{1'b0}};
                end else if (state == COMPUTE) begin
                    partial_sum[m_idx] <= sum_out;
                end
            end
        end
    endgenerate

    // Control FSM
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            done <= 1'b0;
            output_activations <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                // Wait one cycle for loading
                next_state = COMPUTE;
            end
            COMPUTE: begin
                // After computation cycles
                // Here, for simplicity, assume fixed cycles
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data loading (simplified)
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // reset
        end else begin
            case (state)
                IDLE: begin
                    // Wait for start
                end
                LOAD: begin
                    // Load input image
                    input_buffer <= input_image;
                    // Load weights
                    weight_buffer <= weights;

                    // Parse input pixels into array
                    for (integer i = 0; i < N*N; i = i + 1) begin
                        input_data[i] <= input_image[(i+1)*BF16_WIDTH-1 -: BF16_WIDTH];
                    end

                    // Parse weights into array
                    for (integer m = 0; m < M; m = m + 1) begin
                        for (integer n = 0; n < N; n = n + 1) begin
                            weight_data[m][n] <= weights[(m*N + n + 1)*BF16_WIDTH-1 -: BF16_WIDTH];
                        end
                    end
                end
                COMPUTE: begin
                    // Computation happens in PEs
                end
                DONE: begin
                    // Output final results
                    for (integer m = 0; m < M; m = m + 1) begin
                        output_activations[(m+1)*BF16_WIDTH-1 -: BF16_WIDTH] <= partial_sum[m];
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule